local signal = require("../../Signal")
local replica = require("../../Replica")
local util = require("../util")

type onChangedCallback<T> = (value : T, previousValue : T) -> ()
type classContent<T> = {
    value : T,
    _onChangedSignal : signal.classType<T, T>?,
    _replica : replica.replicaServer?,
    _parent : {[any] : any}?,
    _key : any,
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
    replica : replica.replicaServer,
    key : any
) : classType<T>
    local classContent : classContent<T> = {
        value = value,
        _onChangedSignal = nil,
        _replica = replica,
        _key = key 
    }
    local self = setmetatable(classContent, module) :: classType<T>

    return self
end

methods.Set = function<T>(self : classType<T>, value : T)
    local path, replica = util.solvePath(self)
    local previousValue = self.value

    self.value = value
    replica:Set(path, value)

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
