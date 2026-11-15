local Players = game:GetService("Players")

local number = require("@self/fields/number")
local string = require("@self/fields/string")
local table_ = require("@self/fields/table")
local boolean = require("@self/fields/boolean")
local profileStore = require("./ProfileStore")
local signal = require("./Signal")
local replica = require("./Replica")

local replicaServer = replica.server()
local playerDataToken = replicaServer.Token("PlayerData")

type stringClassType = string.classType
type numberClassType = number.classType
type booleanClassType = boolean.classType

type getEntrySignal = <T, U>(
    self : {_table : {[T] : U}}
) -> signal.classType<U, T>
type function tableClassType(T : type, U : type, V : type, isArray : boolean) : type
    local result = types.newtable()

    result:setproperty(types.singleton("_table"), types.newtable(nil, {
        index = T,
        readresult = U,
        writeresult = U,
    }))

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
            error(`unsupported type {type}`)
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

local function transformRuntime<T>(input : T, replica : replica.replicaServer) : transform<T>
    assert(type(input) == "table", "expected a table type")

    local input : {[any] : any} = input
    local result : {[any] : any} = {}

    local function getTransformed(value : any, replica : replica.replicaServer, key : any) : any?
        if type(value) == "number" then
            return number.new(value, replica, key)
        elseif type(value) == "string" then
            return string.new(value, replica, key)
        elseif type(value) == "boolean" then
            return boolean.new(value, replica, key)
        elseif type(value) == "table" then
            local dataHandler = table_.new({}, getTransformed, replica, key)
            local childDataHandlers = transformRuntime(value, replica)

            for key, childDataHandler in pairs(childDataHandlers) do
                dataHandler._table[key] = childDataHandler

                rawset(childDataHandler :: any, "_parent", dataHandler)
            end

            return dataHandler
        end

        return nil
    end

    for key, value in pairs(input) do
        result[key] = getTransformed(value, replica, key) or value
    end

    return result :: transform<T>
end

module.init = function<T>(
    dataTemplate : T,
    storeName : string?,
    useMock : boolean?
) : (Player) -> (transform<T>?)
    local playerStore = profileStore.New(storeName or "PlayerStore", dataTemplate)
    local profiles : {[Player] : profileStore.Profile<any>} = {}
    local playerData : {[Player] : transform<T>} = {}
    local pendingRequests : {[Player] : {thread}} = {}
    local replicas : {[Player] : replica.replicaServer} = {}

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
        local profile = (useMock and playerStore.Mock or playerStore):StartSessionAsync(`{player.UserId}`, {
            Cancel = function()
                return player.Parent ~= Players
            end,
        })
        local data : transform<T>?

        if profile ~= nil then
            profile:AddUserId(player.UserId)

            profile.OnSessionEnd:Connect(function()
                playerData[player] = nil
                profiles[player] = nil

                if replicas[player] then
                    replicas[player]:Destroy()
                    replicas[player] = nil
                end

                player:Kick(`profile session has ended, please rejoin`)
            end)

            if player.Parent == Players then
                local replica = replicaServer.New({
                    Token = playerDataToken :: any,
                    Data = profile.Data,
                })

                replica:Subscribe(player)

                data = transformRuntime(profile.Data, replica)

                playerData[player] = data
                profiles[player] = profile
                replicas[player] = replica
            else
                profile:EndSession()
            end
        else
            player:Kick(`profile failed to load, please rejoin`)
        end

        clearPendingRequests(player, player.Parent == Players and data or nil)
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

    return getPlayerDataAsync
end

return module
