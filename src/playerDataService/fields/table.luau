type classContent<T, U, V> = {
    _table : {[T] : U},
    _transform : (V) -> U?,
}
type classMethods<T, U, V> = {
    -- dictionary
    Get : (self : classType<T, U, V>, key : T) -> U,
    Set : (self : classType<T, U, V>, key : T, value : V) -> U,

    -- array
    Insert : (self : classType<T, U, V>, value : V, position : number?) -> U,
    Remove : (self : classType<T, U, V>, position : number) -> U?,
    Find : (self : classType<T, U, V>, needle : T, init : number?) -> number?
}
export type classType<T, U, V> = classContent<T, U, V> & classMethods<T, U, V>

local module = {}
local methods = {} :: classMethods<unknown, unknown, unknown>
module.__index = function<T, U, V>(self : classContent<T, U, V>, key : any) : any
    local method = (methods :: {[any] : any})[key]

    if method ~= nil then
        return method
    end

    return self._table[key]
end

module.new = function<T, U, V>(
    table : {T},
    transform : (U) -> T?
) : classType<T, U, V>
    local classContent : classContent<T, U, V> = {
        _table = table,
        _transform = transform
    }

    return setmetatable(classContent, module) :: classType<T, U, V>
end

-- dictionary methods

methods.Get = function<T, U, V>(self : classType<T, U, V>, key : T) : U
    return self._table[key]
end

methods.Set = function<T, U, V>(self : classType<T, U, V>, key : T, value : V) : U
    local transformed = (self._transform(value) or value) :: U

    self._table[key] = transformed

    return transformed
end

-- array methods

methods.Insert = function<T, U, V>(self : classType<T, U, V>, value : V, position : number?) : U
    local transformed = (self._transform(value) or value) :: U

    table.insert(self._table, position or 1, transformed)

    return transformed
end

methods.Remove = function<T, U, V>(self : classType<T, U, V>, position : number) : U?
    return table.remove(self._table, position)
end

methods.Find = function<T, U, V>(self : classType<T, U, V>, needle : T, init : number?) : number?
    return table.find(self._table, needle, init)
end

return module
