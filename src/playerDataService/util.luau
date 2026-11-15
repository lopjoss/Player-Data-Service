local replica = require("../Replica")

local module = {}

type dataHandler = {_parent : dataHandler?, _key : any, _replica : replica.replicaServer?}

module.solvePath = function(dataHandler : dataHandler) : ({any}, replica.replicaServer)
    local path = {}
    local parent = dataHandler

    while parent do
        if rawget(parent :: any, "_replica") then
            table.insert(path, 1, parent._key)

            parent = rawget(parent :: any, "_parent")
        else
            error("Failed to complete operation on data handler, did you delete thid data handler previously?")
        end
    end

    return path, dataHandler._replica :: replica.replicaServer
end

return module