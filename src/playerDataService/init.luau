local number = require("@self/fields/number")

type numberClassType = number.classType

type function process<T>(write : type) : type
	assert(write:is("table"), "expected a table type")

	for key, value in write:properties() do
		if value.read then
			if value.read:is("number") then
				write:setproperty(key, numberClassType)
            elseif value.read:is("table") then
                write:setproperty(key, process(value.read))
			end
		end
	end

    return write
end

local module = {}

local function process<T>(input : T & {[any] : any}) : process<T>
    local result : {[any] : any} = {}

    for key, value in pairs(input) do
        if type(value) == "number" then
            result[key] = number.new(value)
        elseif type(value) == "table" then
            result[key] = process(value :: T)
        end
    end

    return result :: process<T>
end

module.process = function<T>(write : T) : process<T>
    assert(type(write) == "table", "Expected a table")

    return process(write)
end

return module
