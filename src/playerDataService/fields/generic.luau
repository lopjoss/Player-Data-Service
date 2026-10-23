type classContent<T> = {
    value : T
}
type classMethods<T> = {
    Set : (self : classType<T>, value : T) -> (),
}
export type classType<T> = classContent<T> & classMethods<T>

local module = {}
local methods = {} :: classMethods<unknown>
module.__index = methods

module.new = function<T>(value : T) : classType<T>
    local classContent : classContent<T> = {
        value = value
    }
    local self = setmetatable(classContent, module) :: classType<T>

    return self
end

methods.Set = function<T>(self : classType<T>, value : T)
    self.value = value
end

return module
