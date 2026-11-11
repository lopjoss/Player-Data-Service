local generic = require("./generic")

type classContent = {}
type classMethods = {
    toggle : (self : classType) -> ()
}
export type classType = generic.classType<boolean> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(value : boolean) : classType
    local self = generic.new<<boolean>>(value)

    return setmetatable(self, module) :: any
end

module.toggle = function(self : classType)
    self:Set(not self.value)
end

return module
