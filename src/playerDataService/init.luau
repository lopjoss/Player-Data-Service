local number = require("@self/fields/number")
local table = require("@self/fields/table")

type tableClassType<T, U, V> = table.classType<T, U, V>
type numberClassType = number.classType

type function transform(write : type) : type
	assert(write:is("table"), "expected a table type")

    write = types.copy(write)

    local function getTransformed(type : type) : type
        if type:is("number") then
            return numberClassType
        elseif type:is("table") then
            local indexer = type:readindexer()

            if indexer then
                return tableClassType(
                    indexer.index,
                    getTransformed(indexer.result),
                    indexer.result
                )
            else
                return transform(type)
            end
        else
            error(`unsupported type {type}`)
        end
    end

	for key, value in write:properties() do
		if value.read then
			write:setproperty(key, getTransformed(value.read))
		end
	end

    return write
end

local module = {}

local function transformRuntime<T>(input : T) : transform<T>
    assert(type(input) == "table", "expected a table type")

    local input : {[any] : any} = input
    local result : {[any] : any} = {}

    local function getTransformed(value : any) : any
        if type(value) == "number" then
            return number.new(value)
        elseif type(value) == "table" then
            return table.new<<any, any, {[any] : any}>>(
                transformRuntime(value),
                getTransformed
            )
        else
            error(`unsupported type {typeof(value)}`)
        end
    end

    for key, value in pairs(input) do
        result[key] = getTransformed(value)
    end

    return result :: transform<T>
end

module.transform = function<T>(input: T) : transform<T>
    assert(type(input) == "table", "expected a table")

    return transformRuntime(input)
end

return module
