local generic = require("./generic")
local replica = require("../../Replica")

type classContent = {}
type classMethods = {}
export type classType = generic.classType<string> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(
    value : string,
    replica : replica.replicaServer,
    key : any
) : classType
    local self = generic.new<<string>>(value, replica, key)

    return setmetatable(self, module) :: any
end

return module
