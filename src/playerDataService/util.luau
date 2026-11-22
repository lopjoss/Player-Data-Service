local RunService = game:GetService("RunService")

local replica = require("../Replica")

local module = {}

export type rawDataTable<T, U> = {
    value : {[T] : U},
    __PDSID : string,
}
export type replicaContext = {
    type : "server",
    replica : replica.replicaServer,
    player : Player,
} | {
    type : "client",
    replica : replica.replicaClient,
}
export type dataHandler = {
    _parent : dataHandler?,
    _key : any,
    _replicaContext : replicaContext?,
    _clientReplicaConnection : replica.replicaConnection?,
}

module.isTable = function(table : any) : boolean
    return rawget(table, "_table") and true or false
end

module.createReplicaContext = function(replica : replica.replicaClient | replica.replicaServer, player : Player?) : replicaContext
    return if RunService:IsServer()
        then player and {type = "server", replica = replica :: replica.replicaServer, player = player} or error("No player received")
        else {type = "client", replica = replica :: replica.replicaClient}
end

module.solvePath = function(dataHandler : dataHandler, useTableIds : boolean?) : ({any}, replicaContext)
    local path = {}
    local parent = dataHandler

    while parent do
        if rawget(parent :: any, "_replicaContext") then
            if module.isTable(parent) then
                if not useTableIds then
                    table.insert(path, 1, "value")
                    table.insert(path, 1, parent._key)
                else
                    local rawDataTable : rawDataTable<any, any> = (parent :: any)._rawDataTable
        
                    table.insert(path, 1, rawDataTable.__PDSID)
                end
            else
                table.insert(path, 1, parent._key)
            end

            parent = rawget(parent :: any, "_parent")
        else
            error("Failed to complete operation on data handler, did you delete this data handler previously?")
        end
    end

    return path, dataHandler._replicaContext :: replicaContext
end

return module