local signal = require("../../Signal")
local util = require("../util")
local replica = require("../../Replica")

type transform<T, U> = (U, replicaContext : util.replicaContext, key : any, parent : {[any] : any}?) -> T?
type classContent<T, U, V> = {
    _table : {[T] : U},
    _onAddedSignal : signal.classType<U, T>?,
    _onRemovedSignal : signal.classType<U, T>?,
    _transform : transform<U, V>,
    _replicaContext : util.replicaContext?,
    _clientReplicaConnection : replica.replicaConnection?,
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
    transform : transform<U, V>,
    replicaContext : util.replicaContext,
    key : any,
    parent : {[any] : any}?
) : classType<T, U, V>
    local classContent : classContent<T, U, V> = {
        _table = table,
        _transform = transform,
        _replicaContext = replicaContext,
        _key = key,
        _parent = parent,
    }
    local self = setmetatable(classContent, module) :: classType<T, U, V>

    if replicaContext.type == "client" then
        self._clientReplicaConnection = replicaContext.replica:OnChange(function(action, onChangedPath, value, key, isDictOp : boolean?)
            if action == "Set" and isDictOp or action == "TableInsert" or action == "TableRemove" then
                local path = util.solvePath(self)
            
                if action == "Set" and #path + 1 == #onChangedPath or #path == #onChangedPath then
                    for i, key in ipairs(path) do
                        if key ~= onChangedPath[i] then
                            return
                        end
                    end

                    if action == "TableInsert" then
                        self:Insert(value, key)
                    elseif action == "TableRemove" then
                        self:Remove(key)
                    elseif action == "Set" then
                        key = onChangedPath[#onChangedPath]

                        if value ~= nil then
                            self:Set(key, value)
                        else
                            self:Delete(key)
                        end
                    end
                end
            end
        end)
    end

    return self
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

local function destroyDataHandler(dataHandler : util.dataHandler)
    local connection = rawget(dataHandler :: any, "_clientReplicaConnection") :: replica.replicaConnection?
    
    if 
        dataHandler._replicaContext
        and dataHandler._replicaContext.type == "client"
        and connection
    then
        connection:Disconnect()
    end
    
    rawset(dataHandler :: any, "_replicaContext", nil)
end

methods.Set = function<T, U, V>(self : classType<T, U, V>, key : T, value : V) : U
    local path, replicaContext = util.solvePath(self)
    local transformed = (self._transform(value, replicaContext, key, self :: {[any] : any}) or value) :: U
    local previousValue = self._table[key]
    local onAddedSignal : signal.classType<U, T>? = rawget(self :: any, "_onAddedSignal")

    self._table[key] = transformed

    if replicaContext.type == "server" then
        table.insert(path, key)

        replicaContext.replica:Set(path, value, true)
    end

    if previousValue ~= nil then
        local onRemovedSignal : signal.classType<U, T>? = rawget(self :: any, "_onRemovedSignal")

        destroyDataHandler(previousValue)
        
        if onRemovedSignal then
            onRemovedSignal:Fire(previousValue, key)
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
        local path, replicaContext = util.solvePath(self)

        if replicaContext.type == "server" then
            table.insert(path, key)

            replicaContext.replica:Set(path, nil, true)
        end

        self._table[key] = nil

        destroyDataHandler(removed)

        if onRemovedSignal then
            onRemovedSignal:Fire(removed, key)
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
    local path, replicaContext = util.solvePath(self)
    local onAddedSignal : signal.classType<U, T>? = rawget(self :: any, "_onAddedSignal")
    
    position = position and math.floor(position)
    position = position and (if position > #self._table then #self._table + 1
        elseif position <= 0 then 1 else position) or #self._table + 1

    local transformed = (self._transform(value, replicaContext, position :: T, self :: {[any] : any}) or value) :: U

    table.insert(self._table, position, transformed)
    
    if replicaContext.type == "server" then
        replicaContext.replica:TableInsert(path, value, position)
    end
    
    self:_UpdateKeys()

    if onAddedSignal then
        onAddedSignal:Fire(transformed, position :: T)
    end

    return transformed
end

methods.Remove = function<T, U, V>(self : classType<T, U, V>, position : number?) : U?
    if #self._table > 0 then
        local path, replicaContext = util.solvePath(self)
        
        position = position and math.floor(position)
        position = position and (if position > #self._table then #self._table
            elseif position <= 0 then 1 else position) or #self._table
            
        local removed = table.remove(self._table, position)

        if replicaContext.type == "server" then
            replicaContext.replica:TableRemove(path, position)
        end
        
        if removed ~= nil then        
            destroyDataHandler(removed)

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
