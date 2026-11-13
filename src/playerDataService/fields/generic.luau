local signal = require("../../Signal")

type onChangedCallback<T> = (value : T, previousValue : T) -> ()
type classContent<T> = {
    value : T,
    _onChangedSignal : signal.classType<T, T>?,
    _rawDataParent : {[any] : any}?,
    _rawDataKey : any,
}
type classMethods<T> = {
    Set : (self : classType<T>, value : T) -> (),
    OnChanged : (self : classType<T>) -> signal.classType<T, T>,
}
export type classType<T> = classContent<T> & classMethods<T>

local module = {}
local methods = {} :: classMethods<unknown>
module.__index = methods

module.new = function<T>(value : T, rawDataParent : {[any] : any}, rawDataKey : any) : classType<T>
    local classContent : classContent<T> = {
        value = value,
        _onChangedSignal = nil,
        _rawDataParent = rawDataParent,
        _rawDataKey = rawDataKey,
    }
    local self = setmetatable(classContent, module) :: classType<T>

    return self
end

methods.Set = function<T>(self : classType<T>, value : T)
    if self._rawDataParent then
        local previousValue = self.value

        self.value = value
        self._rawDataParent[self._rawDataKey] = value

        if self._onChangedSignal then
            self._onChangedSignal:Fire(self.value, previousValue)
        end
    else
        warn(debug.traceback("Cannot call Set on a data handler that has no raw data parent, did you delete this data previously?"))
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
