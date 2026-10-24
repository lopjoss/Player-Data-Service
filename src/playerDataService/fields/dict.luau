type classContent<T, U, V> = {
    _table : {[T] : U},
    _transform : (V) -> U?,
}
type classMethods<T, U, V> = {
    Get : (self : classType<T, U, V>, key : T) -> U,
    Set : (self : classType<T, U, V>, key : T, value : V) -> U,
}
export type classType<T, U, V> = classContent<T, U, V> & classMethods<T, U, V>

local module = {}
local methods = {} :: classMethods<unknown, unknown, unknown>

module.new = function<T, U, V>(
    table : {[T] : U},
    transform : (V) -> U?
) : classType<T, U, V>
    local classContent : classContent<T, U, V> = {
        _table = table,
        _transform = transform
    }

    return setmetatable(classContent, {
        __index = function(self : classContent<T, U, V>, key : any) : any
            local method = (methods :: {[any] : any})[key]

            if method ~= nil then
                return method
            end

            return self._table[key]
        end
    }) :: classType<T, U, V>
end

methods.Get = function<T, U, V>(self : classType<T, U, V>, key : T) : U
    return self._table[key]
end

methods.Set = function<T, U, V>(self : classType<T, U, V>, key : T, value : V) : U
    local transformed = (self._transform(value) or value) :: U

    self._table[key] = transformed

    return transformed
end

return module
