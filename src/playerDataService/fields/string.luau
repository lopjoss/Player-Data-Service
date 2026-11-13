local generic = require("./generic")

type classContent = {}
type classMethods = {}
export type classType = generic.classType<string> & classContent & classMethods

local module = {}
local methods = setmetatable({}, generic) :: classMethods
module.__index = methods

module.new = function(value : string, rawDataParent : {[any] : any}, rawDataKey : any) : classType
    local self = generic.new<<string>>(value, rawDataParent, rawDataKey)

    return setmetatable(self, module) :: any
end

return module
