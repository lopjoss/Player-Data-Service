local generic = require("./generic")
local replica = require("../../Replica")

type classContent = {}
type classMethods = {
    Increment : (self : classType, amount : number) -> (),
    Decrement : (self : classType, amount : number) -> (),
}
export type classType = generic.classType<number> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(
    value : number,
    replica : replica.replicaServer,
    key : any
) : classType
    local self = generic.new<<number>>(value, replica, key)

    return setmetatable(self, module) :: any
end

methods.Increment = function(self : classType, amount : number)
    self:Set(self.value + amount)
end

methods.Decrement = function(self : classType, amount : number)
    self:Set(self.value - amount)
end

return module
