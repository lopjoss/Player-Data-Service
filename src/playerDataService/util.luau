local RunService = game:GetService("RunService")

local replica = require("../Replica")

local module = {}

export type rawDataWrapper<T> = {
    value : T,
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
    _rawDataWrapper : rawDataWrapper<any>,
    _replicaContext : replicaContext?,
    _replicaConnection : replica.replicaConnection?,
    _onPathChanged : (() -> ())?,
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
            if not useTableIds then
                table.insert(path, 1, "value")
                table.insert(path, 1, parent._key)
            else
                local rawDataWrapper : rawDataWrapper<any> = (parent :: any)._rawDataWrapper
    
                table.insert(path, 1, rawDataWrapper.__PDSID)
            end

            parent = rawget(parent :: any, "_parent")
        else
            error("Failed to complete operation on data handler, did you delete this data handler previously?")
        end
    end

    return path, dataHandler._replicaContext :: replicaContext
end

return module