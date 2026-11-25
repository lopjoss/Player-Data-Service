local generic = require("./generic")
local util = require("../util")

type classContent = {}
type classMethods = {}
export type classType = generic.classType<string> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(
    value : string,
    replicaContext : util.replicaContext,
    key : any,
    parent : {[any] : any}?,
    rawDataWrapper : util.rawDataWrapper<string>
) : classType
    local self = generic.new<<string>>(value, replicaContext, key, parent, rawDataWrapper)

    return setmetatable(self, module) :: any
end

return module
