type classContent<T, U, V> = {
    _table : {[T] : U},
    _rawDataTable : {[T] : V},
    _transform : (V, rawDataParent : {[T] : V}, rawDataKey : T) -> U?,
}
type classMethods<T, U, V> = {
    -- dictionary
    Get : (self : classType<T, U, V>, key : T) -> U,
    Set : (self : classType<T, U, V>, key : T, value : V) -> U,

    -- array
    _UpdateDataHandlerKeys : (self : classType<T, U, V>) -> (),
    Insert : (self : classType<T, U, V>, value : V, position : number?) -> U,
    Remove : (self : classType<T, U, V>, position : number) -> U?,
    Find : (self : classType<T, U, V>, needle : U, init : number?) -> number?
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
    table : {[T] : U},
    rawDataTable : {[T] : V},
    transform : (V, {[T] : V}, T) -> U?
) : classType<T, U, V>
    local classContent : classContent<T, U, V> = {
        _table = table,
        _rawDataTable = rawDataTable,
        _transform = transform
    }

    return setmetatable(classContent, module) :: classType<T, U, V>
end

-- dictionary methods

methods.Get = function<T, U, V>(self : classType<T, U, V>, key : T) : U
    return self._table[key]
end

methods.Set = function<T, U, V>(self : classType<T, U, V>, key : T, value : V) : U
    local transformed = (self._transform(value, self._rawDataTable, key) or value) :: U
    local previousValue = self._table[key]

    if previousValue and rawget(previousValue, "_rawDataParent") then
        rawset(previousValue, "_rawDataParent", nil)
    end

    self._table[key] = transformed
    self._rawDataTable[key] = value

    return transformed
end

-- array methods

methods._UpdateDataHandlerKeys = function<T, U, V>(self : classType<T, U, V>)
    for key, dataHandler in pairs(self._table) do
        if rawget(dataHandler, "_rawDataKey") then
            rawset(dataHandler, "_rawDataKey", key)
        end
    end
end

methods.Insert = function<T, U, V>(self : classType<T, U, V>, value : V, position : number?) : U
    local last = #self._rawDataTable
    local index = math.floor(position or last + 1)
    local key = index :: T

    if index >= 1 and index <= last then
        local transformed = (self._transform(value, self._rawDataTable, key) or value) :: U
    
        table.insert(self._rawDataTable, index, value)

        table.move(self._table, index, last, index + 1)
        self._table[key] = transformed

        self:_UpdateDataHandlerKeys()

        return transformed
    else
        return self:Set(key, value)
    end
end

methods.Remove = function<T, U, V>(self : classType<T, U, V>, position : number) : U?
    local last = #self._rawDataTable
    local index = math.floor(position)
    
    if index >= 1 and index <= last then
        local removed = self._table[index :: T]

        table.remove(self._rawDataTable, index)
        
        table.move(self._table, index + 1, last, index)
        self._table[last :: T] = nil
    
        if removed ~= nil and rawget(removed, "_rawDataParent") then
            rawset(removed, "_rawDataParent", nil)
        end
    
        self:_UpdateDataHandlerKeys()
    
        return removed
    end

    return nil
end

methods.Find = function<T, U, V>(self : classType<T, U, V>, needle : U, init : number?) : number?
    return table.find(self._table, needle, init)
end

return module
