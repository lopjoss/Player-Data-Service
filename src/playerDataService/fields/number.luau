local generic = require("./generic")

type classContent = {}
type classMethods = {
    Increment : (self : classType, amount : number) -> (),
    Decrement : (self : classType, amount : number) -> (),
}
export type classType = generic.classType<number> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(value : number) : classType
    local self = generic.new<<number>>(value)

    return setmetatable(self, module) :: any
end

methods.Increment = function(self : classType, amount : number)
    self:Set(self.value + amount)
end

methods.Decrement = function(self : classType, amount : number)
    self:Set(self.value - amount)
end

return module
