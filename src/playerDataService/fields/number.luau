local generic = require("./generic")

type classContent = {}
type classMethods = {}
export type classType = generic.classType<number> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(value : number) : classType
    local self = generic.new<<number>>(value)

    return setmetatable(self, module) :: any
end

return module
