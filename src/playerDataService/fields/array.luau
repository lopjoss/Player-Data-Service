type classContent<T, U> = {
    _table : {T},
    _transform : (U) -> T?,
}
type classMethods<T, U> = {
    Insert : (self : classType<T, U>, value : U, position : number?) -> T,
    Remove : (self : classType<T, U>, position : number) -> T?,
    Get : (self : classType<T, U>, position : number) -> T,
    Find : (self : classType<T, U>, needle : T, init : number?) -> number?
}
export type classType<T, U> = classContent<T, U> & classMethods<T, U>

local module = {}
local methods = {} :: classMethods<unknown, unknown>

module.new = function<T, U>(
    table : {T},
    transform : (U) -> T?
) : classType<T, U>
    local classContent : classContent<T, U> = {
        _table = table,
        _transform = transform
    }

    return setmetatable(classContent, {
        __index = function(self : classContent<T, U>, key : any) : any
            local method = (methods :: {[any] : any})[key]

            if method ~= nil then
                return method
            end

            return self._table[key]
        end
    }) :: classType<T, U>
end

methods.Insert = function<T, U>(self : classType<T, U>, value : U, position : number?) : T
    local transformed = (self._transform(value) or value) :: T

    table.insert(self._table, position or 1, transformed)

    return transformed
end

methods.Remove = function<T, U>(self : classType<T, U>, position : number) : T?
    return table.remove(self._table, position)
end

methods.Get = function<T, U>(self : classType<T, U>, position : number) : T
    return self._table[position]
end

methods.Find = function<T, U>(self : classType<T, U>, needle : T, init : number?) : number?
    return table.find(self._table, needle, init)
end

return module
