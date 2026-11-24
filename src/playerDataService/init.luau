local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local number = require("@self/fields/number")
local string = require("@self/fields/string")
local table_ = require("@self/fields/table")
local util = require("@self/util")
local boolean = require("@self/fields/boolean")
local signal = require("./Signal")
local replica = require("./Replica")

type stringClassType = string.classType
type numberClassType = number.classType
type booleanClassType = boolean.classType

type schedulerOp = {
    method : string,
    values : {any},
    id : string,
    schedulerId : string,
}

type scheduler = {
    path : {any},
    creationTime : number,
    delay : number,
    ops : {schedulerOp},
}

type storeDataWrapper<T> = {
    data : T,
    schedulers : {[string] : scheduler},
}

type getEntrySignal = <T, U>(
    self : {_table : {[T] : U}}
) -> signal.classType<U, T>
type rawDataTable<T, U> = util.rawDataTable<T, U>
type function tableClassType(T : type, U : type, V : type, isArray : boolean) : type
    local result = types.newtable()

    result:setproperty(types.singleton("_table"), types.newtable(nil, {
        index = T,
        readresult = U,
        writeresult = U,
    }))

    result:setproperty(types.singleton("_rawDataTable"), rawDataTable(T, V))

    local function addMethod(
        name : string,
        parameters : {type},
        returns : {type}
    )
        result:setproperty(types.singleton(name), types.newfunction(
            {head = parameters},
            {head = returns}
        ))
    end
    
    addMethod("Get", {result, T}, {U})
    addMethod("Iterate", {result}, {types.newfunction({}, {head = {types.optional(T), U}})})
    result:setproperty(types.singleton("OnAdded"), getEntrySignal)
    result:setproperty(types.singleton("OnRemoved"), getEntrySignal)

    if isArray then
        addMethod("Insert", {result, V, types.optional(types.number)}, {U})
        addMethod("Remove", {result, types.optional(types.number)}, {types.optional(U)})
        addMethod("Find", {result, U, types.optional(types.number)}, {types.optional(types.number)})
    else
        addMethod("Set", {result, T, V}, {U})
        addMethod("Delete", {result, T}, {types.optional(U)})
    end

    return result
end

type function transform(write : type) : type
	assert(write:is("table"), "expected a table type")

    write = types.copy(write)

    local function getTransformed(type : type) : type
        if type:is("number") then
            return numberClassType
        elseif type:is("string") then
            return stringClassType
        elseif type:is("boolean") then
            return booleanClassType
        elseif type:is("table") then
            local indexer = type:readindexer()

            if indexer then
                if indexer.index:is("number") then
                    return tableClassType(
                        types.number,
                        getTransformed(indexer.result),
                        indexer.result,
                        true
                    )
                else
                    return tableClassType(
                        indexer.index,
                        getTransformed(indexer.result),
                        indexer.result,
                        false
                    )
                end
            else
                return transform(type)
            end
        else
            error(`Unsupported type {type}`)
        end
    end

	for key, value in write:properties() do
		if value.read then
			write:setproperty(key, getTransformed(value.read))
		end
	end

    return write
end

local module = {}

local function transformRuntime<T>(input : T, replicaContext : util.replicaContext, parent : any?) : transform<T>
    assert(type(input) == "table", "expected a table type")

    local result = {}

    local function getTransformed(
        value : any,
        replicaContext : util.replicaContext,
        key : any,
        parent : any?
    ) : (any, util.rawDataTable<any, any>?)
        if type(value) == "number" then
            return number.new(value, replicaContext, key, parent)
        elseif type(value) == "string" then
            return string.new(value, replicaContext, key, parent)
        elseif type(value) == "boolean" then
            return boolean.new(value, replicaContext, key, parent)
        elseif type(value) == "table" then
            local rawDataTable : util.rawDataTable<any, any> = value.__PDSID and value or {
                value = value,
                __PDSID = HttpService:GenerateGUID(false)
            }
            local dataHandler = table_.new({}, getTransformed, replicaContext, key, parent, rawDataTable)
            local childDataHandlers = transformRuntime(rawDataTable.value, replicaContext, dataHandler)

            for key, childDataHandler in pairs(childDataHandlers) do
                dataHandler._table[key] = childDataHandler
            end

            return dataHandler, rawDataTable
        else
            error(`Unsupported type {type(value)}`)
        end
    end

    for key, value in pairs(input) do
        local dataHandler, rawDataTable = getTransformed(value, replicaContext, key, parent, input)

        result[key] = dataHandler
        
        if rawDataTable then
            (input :: any)[key] = rawDataTable
        end
    end

    return result :: transform<T>
end

local function reconcile<T>(data : T & {any}, reference : any, skipIndices : {any}?, dontWrapTables : boolean?) : T
    for key, value in pairs(reference) do
        if not skipIndices or not table.find(skipIndices, key) then
            if type(value) ~= "table" then
                if data[key] == nil then
                    data[key] = value
                end
            else
                local rawDataTable : util.rawDataTable<any, any>? = not dontWrapTables and (data[key] and data[key].__PDSID and data[key] or {
                    value = data[key] or {},
                    __PDSID = HttpService:GenerateGUID(false)
                }) or nil
                local reconciled = reconcile(rawDataTable and rawDataTable.value or data[key] or {}, value, nil, dontWrapTables)

                data[key] = rawDataTable or reconciled
            end
        end
    end

    return data
end

module.init = function<T>(
    dataTemplate : T,
    storeName : string?,
    useMock : boolean?,
    dontReconcile : boolean?
) : {
    server : {
        getPlayerDataAsync : (Player) -> transform<T>?,
        createScheduler : <T>(dataHandler : T, delay : number) -> (T, string),
        destroyScheduler : (schedulerId : string, player : Player?) -> ()
    },
    client : {
        getPlayerDataAsync : () -> transform<T>,
    },
}
    if RunService:IsServer() then
        local profileStore = require("./ProfileStore")
        local replicaServer = replica.server()

        local wrappedStoreData : storeDataWrapper<T> = {
            data = dataTemplate,
            schedulers = {}
        }
        local playerDataToken = replicaServer.Token("PlayerData")
        local playerStore = profileStore.New(storeName or "PlayerStore", wrappedStoreData)
        local profiles : {[Player] : profileStore.Profile<storeDataWrapper<T>>} = {}
        local playerData : {[Player] : transform<T>} = {}
        local pendingRequests : {[Player] : {thread}} = {}
        local replicas : {[Player] : replica.replicaServer} = {}

        local function destroyScheduler(schedulerId : string, player : Player?)
            local function destroy(profile : profileStore.Profile<storeDataWrapper<T>>?)
                if profile then
                    if profile:IsActive() then
                        profile.Data.schedulers[schedulerId] = nil
                    else
                        error("Profile is inactive")
                    end
                else
                    error("No profile found")
                end
            end

            if not player then
                for _, profile in pairs(profiles) do
                    if profile.Data.schedulers[schedulerId] then
                        destroy(profile)

                        return
                    end
                end

                error("No profile found")
            else
                destroy(profiles[player])
            end
        end

        local function processSchedulerOps(player : Player, schedulerId : string)
            local profile = profiles[player]
            local data = playerData[player]

            if data and profile and profile:IsActive() then
                local scheduler = profile.Data.schedulers[schedulerId]

                if scheduler then
                    local field : any = data
    
                    local function findTableDataHandlerFromId(dataHandlers : {tableClassType<any, any, any, false>}, id : string) : any
                        local field : any
    
                        for _, dataHandler in dataHandlers do
                            if util.isTable(dataHandler) then
                                if dataHandler._rawDataTable.__PDSID == id then
                                    field = dataHandler
    
                                    break
                                end
                            end
                        end
    
                        if field then
                            return field
                        else
                            destroyScheduler(schedulerId, player)
    
                            error(`Failed to complete scheduled operations: could not find table data handler with id {id}`)
                        end
                    end
                    
                    for _, key in ipairs(scheduler.path) do
                        if util.isTable(field) then
                            local table_ = field :: tableClassType<any, any, any, false>
    
                            field = table_:Get(key) or findTableDataHandlerFromId(table_._table, key)
                        else
                            field = field[key] or findTableDataHandlerFromId(field, key)
                        end
                    end
    
                    while #scheduler.ops > 0 do
                        local op = scheduler.ops[1]

                        field[op.method](field, table.unpack(op.values))

                        table.remove(scheduler.ops, 1)
                    end
    
                    destroyScheduler(schedulerId, player)
                end
            end
        end

        local function createScheduler<T>(dataHandler : T, delay : number) : (T, string)
            local path, replicaContext = util.solvePath(dataHandler, true)
            
            if replicaContext.type == "server" then
                local profile = profiles[replicaContext.player]
                
                if profile then
                    if profile:IsActive() then
                        local schedulerId = HttpService:GenerateGUID(false)
                        local scheduler : scheduler = {
                            path = path,
                            creationTime = workspace:GetServerTimeNow(),
                            delay = delay,
                            ops = {},
                        }

                        profile.Data.schedulers[schedulerId] = scheduler

                        task.delay(delay, function()
                            processSchedulerOps(replicaContext.player, schedulerId)
                        end)

                        return setmetatable({}, {
                            __index = function(_, methodName : string)
                                return function(_, ...)
                                    if profile:IsActive() then
                                        local scheduler = profile.Data.schedulers[schedulerId]

                                        if scheduler then
                                            local op : schedulerOp = {
                                                method = methodName,
                                                values = table.pack(...),
                                                id = HttpService:GenerateGUID(),
                                                schedulerId = schedulerId,
                                            }

                                            table.insert(scheduler.ops, op)
                                        else
                                            error("Scheduler has been destroyed")
                                        end
                                    else
                                        error("Profile is inactive")
                                    end
                                end
                            end,
                        }) :: T, schedulerId
                    else
                        error("Profile is inactive")
                    end
                else
                    error("No profile found")
                end
            else
                error("ReplicaContext is not set to server")
            end
        end

        local function getPlayerDataAsync(player : Player) : transform<T>?
            if player.Parent == Players then
                local playerData = playerData[player]

                if playerData then
                    return playerData
                else
                    pendingRequests[player] = pendingRequests[player] or {}

                    table.insert(pendingRequests[player], coroutine.running())

                    return coroutine.yield<<(), (transform<T>?)>>()
                end
            else
                return nil
            end
        end

        local function clearPendingRequests(player : Player, playerData : transform<T>?)
            local playerPendingRequests = pendingRequests[player]

            if playerPendingRequests then
                pendingRequests[player] = nil
                
                for _, thread in ipairs(playerPendingRequests) do
                    task.spawn(thread, player.Parent == Players and playerData or nil)
                end
            end
        end

        local function initPlayer(player : Player)
            if replicaServer then
                local profile = (useMock and playerStore.Mock or playerStore):StartSessionAsync(`{player.UserId}`, {
                    Cancel = function()
                        return player.Parent ~= Players
                    end,
                })
                local data : transform<T>?

                if profile ~= nil then
                    local thread : thread?

                    print("Loaded profile:", profile)

                    profile:AddUserId(player.UserId)
                    
                    if not dontReconcile then
                        reconcile(profile.Data :: any, wrappedStoreData, {"data"}, true)
                        reconcile(profile.Data.data, wrappedStoreData.data)
                    end

                    profile.OnSessionEnd:Connect(function()
                        playerData[player] = nil
                        profiles[player] = nil

                        if thread then
                            task.spawn(thread)
                        end

                        if replicas[player] then
                            replicas[player]:Destroy()
                            replicas[player] = nil
                        end

                        player:Kick(`profile session has ended, please rejoin`)
                    end)

                    profiles[player] = profile

                    if player.Parent == Players then
                        if not replicaServer.ReadyPlayers[player] then
                            thread = coroutine.running()

                            local conn : replica.replicaConnection
                            conn = replicaServer.NewReadyPlayer:Connect(function(readyPlayer)
                                if readyPlayer == player then
                                    conn:Disconnect()

                                    task.spawn(thread :: thread)
                                end
                            end)

                            coroutine.yield()

                            conn:Disconnect()

                            thread = nil
                        end

                        if replicaServer.ReadyPlayers[player] then
                            local replica = replicaServer.New({
                                Token = playerDataToken :: any,
                                Data = profile.Data.data,
                            })

                            replica:Subscribe(player)
    
                            data = transformRuntime(profile.Data.data, util.createReplicaContext(replica, player))
    
                            playerData[player] = data
                            replicas[player] = replica
    
                            for schedulerId, scheduler in pairs(profile.Data.schedulers) do
                                local delay = scheduler.creationTime + scheduler.delay - workspace:GetServerTimeNow()
    
                                task.delay(delay, function()
                                    processSchedulerOps(player, schedulerId)
                                end)
                            end
                        end
                    else
                        profile:EndSession()
                    end
                else
                    player:Kick("profile failed to load, please rejoin")
                end

                clearPendingRequests(player, data)
            end
        end

        Players.PlayerAdded:Connect(function(player)
            initPlayer(player)
        end)

        Players.PlayerRemoving:Connect(function(player)
            local profile = profiles[player]

            if profile ~= nil then
                profile:EndSession()
            end
        end)

        for _, player in ipairs(Players:GetPlayers()) do
            task.spawn(initPlayer, player)
        end

        return {
            server = {
                getPlayerDataAsync = getPlayerDataAsync,
                createScheduler = createScheduler,
                destroyScheduler = destroyScheduler,
            },
            client = nil :: any,
        }
    else
        local replicaClient = replica.client()

        replicaClient.RequestData()

        local function getPlayerDataAsync() : transform<T>
            local thread = coroutine.running()

            local conn : replica.replicaConnection
            conn = replicaClient.OnNew("PlayerData", function(replica)
                conn:Disconnect()

                task.spawn(thread, replica)
            end)

            local replica = coroutine.yield<<(), (replica.replicaClient)>>()
            local playerData = transformRuntime(replica.Data :: T, util.createReplicaContext(replica))

            return playerData
        end

        return {
            server = nil :: any,
            client = {
                getPlayerDataAsync = getPlayerDataAsync,
            },
        }
    end
end

return module
