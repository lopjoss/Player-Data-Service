local signal = require(script.Parent.Parent.Parent.Signal)

type classContent<T, U, V> = {
    _table : {[T] : U},
    _onAddedSignal : signal.classType<U, T>?,
    _onRemovedSignal : signal.classType<U, T>?,
    _rawDataTable : {[T] : V},
    _transform : (V, rawDataParent : {[T] : V}, rawDataKey : T) -> U?,
}
type classMethods<T, U, V> = {
    Get : (self : classType<T, U, V>, key : T) -> U,
    OnAdded : (self : classType<T, U, V>) -> signal.classType<U, T>,
    OnRemoved : (self : classType<T, U, V>) -> signal.classType<U, T>,
    Iterate : (self : classType<T, U, V>) -> () -> (T?, U),

    -- dictionary
    Set : (self : classType<T, U, V>, key : T, value : V) -> U,
    Delete : (self : classType<T, U, V>, key : T) -> U?,

    -- array
    _UpdateDataHandlerKeys : (self : classType<T, U, V>) -> (),
    Insert : (self : classType<T, U, V>, value : V, position : number?) -> U,
    Remove : (self : classType<T, U, V>, position : number?) -> U?,
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

methods.OnAdded = function<T, U, V>(self : classType<T, U, V>) : signal.classType<U, T>
    local onAddedSignal : signal.classType<U, T>? = rawget(self :: any, "_onAddedSignal")

    if onAddedSignal then
        return onAddedSignal
    else
        local signal = signal.new()

        self._onAddedSignal = signal

        return signal
    end
end

methods.OnRemoved = function<T, U, V>(self : classType<T, U, V>) : signal.classType<U, T>
    local onRemovedSignal : signal.classType<U, T>? = rawget(self :: any, "_onRemovedSignal")
    
    if onRemovedSignal then
        return onRemovedSignal
    else
        local signal = signal.new()

        self._onRemovedSignal = signal

        return signal
    end
end

methods.Iterate = function<T, U, V>(self : classType<T, U, V>) : () -> (T?, U)
    local key : T? = nil

    return function()
        local value : U
        key, value = next(self._table, key)

        return key, value
    end
end

methods.Get = function<T, U, V>(self : classType<T, U, V>, key : T) : U
    return self._table[key]
end

-- dictionary methods

methods.Set = function<T, U, V>(self : classType<T, U, V>, key : T, value : V) : U
    local transformed = (self._transform(value, self._rawDataTable, key) or value) :: U
    local previousValue = self._table[key]
    local onAddedSignal : signal.classType<U, T>? = rawget(self :: any, "_onAddedSignal")

    self._table[key] = transformed
    self._rawDataTable[key] = value

    if previousValue ~= nil then
        local onRemovedSignal : signal.classType<U, T>? = rawget(self :: any, "_onRemovedSignal")

        if onRemovedSignal then
            onRemovedSignal:Fire(previousValue, key)
        end

        if rawget(previousValue, "_rawDataParent") then
            rawset(previousValue, "_rawDataParent", nil)
        end
    end

    if onAddedSignal then
        onAddedSignal:Fire(transformed, key)
    end

    return transformed
end

methods.Delete = function<T, U, V>(self : classType<T, U, V>, key : T) : U?
    local removed = self._table[key]

    if removed ~= nil then
        local onRemovedSignal : signal.classType<U, T>? = rawget(self :: any, "_onRemovedSignal")

        self._table[key] = nil
        self._rawDataTable[key] = nil

        if onRemovedSignal then
            onRemovedSignal:Fire(removed, key)
        end

        if rawget(removed, "_rawDataParent") then
            rawset(removed, "_rawDataParent", nil)
        end
    end

    return removed
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
        local onAddedSignal : signal.classType<U, T>? = rawget(self :: any, "_onAddedSignal")
    
        table.insert(self._rawDataTable, index, value)

        table.move(self._table, index, last, index + 1)
        self._table[key] = transformed

        if onAddedSignal then
            onAddedSignal:Fire(transformed, key)
        end

        self:_UpdateDataHandlerKeys()

        return transformed
    else
        return self:Set(key, value)
    end
end

methods.Remove = function<T, U, V>(self : classType<T, U, V>, position : number?) : U?
    local last = #self._rawDataTable
    local index = math.floor(position or last)
    local key = index :: T
    
    if index >= 1 and index <= last then
        local removed = self._table[key]

        table.remove(self._rawDataTable, index)
        
        table.move(self._table, index + 1, last, index)
        self._table[last :: T] = nil
    
        if removed ~= nil then
            local onRemovedSignal : signal.classType<U, T>? = rawget(self :: any, "_onRemovedSignal")

            if onRemovedSignal then
                onRemovedSignal:Fire(removed, key)
            end
            
            if rawget(removed, "_rawDataParent") then
                rawset(removed, "_rawDataParent", nil)
            end
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
