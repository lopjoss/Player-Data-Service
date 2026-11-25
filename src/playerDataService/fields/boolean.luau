local generic = require("./generic")
local util = require("../util")

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
    replicaContext : util.replicaContext,
    key : any,
    parent : {[any] : any}?,
    rawDataWrapper : util.rawDataWrapper<boolean>
) : classType
    local self = generic.new<<boolean>>(value, replicaContext, key, parent, rawDataWrapper)

    return setmetatable(self, module) :: any
end

methods.Toggle = function(self : classType)
    self:Set(not self.value)
end

return module
