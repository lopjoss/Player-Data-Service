local generic = require("./generic")

type classContent = {}
type classMethods = {}
export type classType = generic.classType<string> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(value : string) : classType
    local self = generic.new<<string>>(value)

    return setmetatable(self, module) :: any
end

return module
