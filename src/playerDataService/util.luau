local RunService = game:GetService("RunService")

local replica = require("../Replica")

local module = {}

export type replicaContext = {
    type : "server",
    replica : replica.replicaServer
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

module.getReplicaContext = function(replica : replica.replicaClient | replica.replicaServer) : replicaContext
    return if RunService:IsServer()
        then {type = "server", replica = replica :: replica.replicaServer}
        else {type = "client", replica = replica :: replica.replicaClient}
end

module.solvePath = function(dataHandler : dataHandler) : ({any}, replicaContext)
    local path = {}
    local parent = dataHandler

    while parent do
        if rawget(parent :: any, "_replicaContext") then
            table.insert(path, 1, parent._key)

            parent = rawget(parent :: any, "_parent")
        else
            error("Failed to complete operation on data handler, did you delete this data handler previously?")
        end
    end

    return path, dataHandler._replicaContext :: replicaContext
end

return module