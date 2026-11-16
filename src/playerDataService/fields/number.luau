local generic = require("./generic")
local util = require("../util")

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
    replicaContext : util.replicaContext,
    key : any,
    parent : {[any] : any}?
) : classType
    local self = generic.new<<number>>(value, replicaContext, key, parent)

    return setmetatable(self, module) :: any
end

methods.Increment = function(self : classType, amount : number)
    self:Set(self.value + amount)
end

methods.Decrement = function(self : classType, amount : number)
    self:Set(self.value - amount)
end

return module
