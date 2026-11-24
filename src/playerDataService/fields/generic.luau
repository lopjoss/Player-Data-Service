local signal = require("../../Signal")
local util = require("../util")
local replica = require("../../Replica")

type onChangedCallback<T> = (value : T, previousValue : T) -> ()
type classContent<T> = {
    value : T,
    _onChangedSignal : signal.classType<T, T>?,
    _replicaContext : util.replicaContext?,
    _replicaConnection : replica.replicaConnection?,
    _parent : {[any] : any}?,
    _key : any,
    _onPathChanged : (() -> ())?,
}
type classMethods<T> = {
    Set : (self : classType<T>, value : T) -> (),
    OnChanged : (self : classType<T>) -> signal.classType<T, T>,
}
export type classType<T> = classContent<T> & classMethods<T>

local module = {}
local methods = {} :: classMethods<unknown>
module.__index = methods

module.new = function<T>(
    value : T,
    replicaContext : util.replicaContext,
    key : any,
    parent : {[any] : any}?
) : classType<T>
    local classContent : classContent<T> = {
        value = value,
        _onChangedSignal = nil,
        _replicaContext = replicaContext,
        _key = key,
        _parent = parent,
    }
    local self = setmetatable(classContent, module) :: classType<T>

    if replicaContext.type == "client" then
        local function onPathChanged()
            if self._replicaConnection then
                self._replicaConnection:Disconnect()
            end

            local path = util.solvePath(self)
    
            self._replicaConnection = replicaContext.replica:OnSet(path, function(value, _, isDictOp : boolean?)
                if not isDictOp then
                    self:Set(value)
                end
            end)
        end

        onPathChanged()

        self._onPathChanged = onPathChanged
    end

    return self
end

methods.Set = function<T>(self : classType<T>, value : T)
    local path, replicaContext = util.solvePath(self)
    local previousValue = self.value

    self.value = value
    if replicaContext.type == "server" then
        replicaContext.replica:Set(path, value)
    end

    if self._onChangedSignal then
        self._onChangedSignal:Fire(self.value, previousValue)
    end
end

methods.OnChanged = function<T>(self : classType<T>) : signal.classType<T, T>
    if self._onChangedSignal then
        return self._onChangedSignal
    else
        local signal = signal.new()

        self._onChangedSignal = signal

        return signal
    end
end

return module
