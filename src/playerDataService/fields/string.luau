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
    parent : {[any] : any}?
) : classType
    local self = generic.new<<string>>(value, replicaContext, key, parent)

    return setmetatable(self, module) :: any
end

return module
