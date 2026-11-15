local generic = require("./generic")
local replica = require("../../Replica")

type classContent = {}
type classMethods = {
    Toggle : (self : classType) -> ()
}
export type classType = generic.classType<boolean> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(
    value : boolean,
    replica : replica.replicaServer,
    key : any
) : classType
    local self = generic.new<<boolean>>(value, replica, key)

    return setmetatable(self, module) :: any
end

methods.Toggle = function(self : classType)
    self:Set(not self.value)
end

return module
