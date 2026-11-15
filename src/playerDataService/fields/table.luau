local signal = require("../../Signal")
local replica = require("../../Replica")
local util = require("../util")

type classContent<T, U, V> = {
    _table : {[T] : U},
    _onAddedSignal : signal.classType<U, T>?,
    _onRemovedSignal : signal.classType<U, T>?,
    _transform : (V, replica : replica.replicaServer, key : any) -> U?,
    _replica : replica.replicaServer?,
    _parent : {[any] : any}?,
    _key : any,
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
    _UpdateKeys : (self : classType<T, U, V>) -> (),
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
    transform : (V, replica : replica.replicaServer, path : {any}) -> U?,
    replica : replica.replicaServer,
    key : any
) : classType<T, U, V>
    local classContent : classContent<T, U, V> = {
        _table = table,
        _transform = transform,
        _replica = replica,
        _key = key,
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
    local path, replica = util.solvePath(self)
    local transformed = (self._transform(value, replica, key) or value) :: U
    local previousValue = self._table[key]
    local onAddedSignal : signal.classType<U, T>? = rawget(self :: any, "_onAddedSignal")

    rawset(transformed, "_parent", self)

    self._table[key] = transformed

    table.insert(path, key)
    replica:Set(path, value)

    if previousValue ~= nil then
        local onRemovedSignal : signal.classType<U, T>? = rawget(self :: any, "_onRemovedSignal")

        if onRemovedSignal then
            onRemovedSignal:Fire(previousValue, key)
        end

        if rawget(previousValue, "_replica") then
            rawset(previousValue, "_replica", nil)
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
        local path, replica = util.solvePath(self)

        table.insert(path, key)
        replica:Set(path, nil)

        self._table[key] = nil

        if onRemovedSignal then
            onRemovedSignal:Fire(removed, key)
        end

        if rawget(removed, "_replica") then
            rawset(removed, "_replica", nil)
        end
    end

    return removed
end

-- array methods

methods._UpdateKeys = function<T, U, V>(self : classType<T, U, V>)
    for key, dataHandler in ipairs(self._table) do
        rawset(dataHandler, "_key", key)
    end
end

methods.Insert = function<T, U, V>(self : classType<T, U, V>, value : V, position : number?) : U
    local path, replica = util.solvePath(self)
    local transformed = (self._transform(value, replica, position) or value) :: U
    local onAddedSignal : signal.classType<U, T>? = rawget(self :: any, "_onAddedSignal")
    
    position = position and math.floor(position)
    position = position and (if position > #self._table then #self._table + 1
        elseif position <= 0 then 1 else position) or #self._table + 1

    rawset(transformed, "_parent", self)

    table.insert(self._table, position, transformed)

    replica:TableInsert(path, value, position)
    
    self:_UpdateKeys()

    if onAddedSignal then
        onAddedSignal:Fire(transformed, (position or #self._table) :: T)
    end

    return transformed
end

methods.Remove = function<T, U, V>(self : classType<T, U, V>, position : number?) : U?
    if #self._table > 0 then
        local path, replica = util.solvePath(self)
        
        position = position and math.floor(position)
        position = position and (if position > #self._table then #self._table
            elseif position <= 0 then 1 else position) or #self._table
            
        local removed = table.remove(self._table, position)

        replica:TableRemove(path, position)
        
        if removed ~= nil then        
            if rawget(removed, "_replica") then
                rawset(removed, "_replica", nil)
            end

            self:_UpdateKeys()

            local onRemovedSignal : signal.classType<U, T>? = rawget(self :: any, "_onRemovedSignal")

            if onRemovedSignal then
                onRemovedSignal:Fire(removed, position :: T)
            end
        end

        return removed
    end

    return nil
end

methods.Find = function<T, U, V>(self : classType<T, U, V>, needle : U, init : number?) : number?
    return table.find(self._table, needle, init)
end

return module
