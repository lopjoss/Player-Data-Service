local generic = require("./generic")

type classContent = {}
type classMethods = {
    Toggle : (self : classType) -> ()
}
export type classType = generic.classType<boolean> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(value : boolean, rawDataParent : {[any] : any}, rawDataKey : any) : classType
    local self = generic.new<<boolean>>(value, rawDataParent, rawDataKey)

    return setmetatable(self, module) :: any
end

methods.Toggle = function(self : classType)
    self:Set(not self.value)
end

return module
