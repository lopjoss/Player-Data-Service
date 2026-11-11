--[[
    TODO
    update ancestor tables on generic value change
]]

local number = require("@self/fields/number")
local string = require("@self/fields/string")
local table_ = require("@self/fields/table")

type stringClassType = string.classType
type numberClassType = number.classType
type function tableClassType(T: type, U: type, V: type, isArray : boolean): type
    local result = types.newtable()

    result:setproperty(types.singleton("_table"), types.newtable(nil, {
        index = T,
        readresult = U,
        writeresult = U,
    }))

    result:setproperty(types.singleton("_transform"), types.newfunction(
        {head = {V}},
        {head = {types.optional(U)}}
    ))

    local function addMethod(
        name: string,
        parameters: {type},
        returns: {type}
    )
        result:setproperty(types.singleton(name), types.newfunction(
            {head = parameters},
            {head = returns}
        ))
    end

    if isArray then
        addMethod("Insert", {result, V, types.optional(types.number)}, {U})
        addMethod("Remove", {result, types.number}, {types.optional(U)})
        addMethod("Find", {result, T, types.optional(types.number)}, {types.optional(types.number)})
    else
        addMethod("Get", {result, T}, {U})
        addMethod("Set", {result, T, V}, {U})
    end

    return result
end

type function transform(write : type) : type
	assert(write:is("table"), "expected a table type")

    write = types.copy(write)

    local function getTransformed(type : type) : type
        if type:is("number") then
            return numberClassType
        elseif type:is("string") then
            return stringClassType
        elseif type:is("table") then
            local indexer = type:readindexer()

            if indexer then
                if indexer.index:is("number") then
                    return tableClassType(
                        types.number,
                        getTransformed(indexer.result),
                        indexer.result,
                        true
                    )
                else
                    return tableClassType(
                        indexer.index,
                        getTransformed(indexer.result),
                        indexer.result,
                        false
                    )
                end
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

    local function getTransformed(value : any) : any?
        if type(value) == "number" then
            return number.new(value)
        elseif type(value) == "string" then
            return string.new(value)
        elseif type(value) == "table" then
            return table_.new(transformRuntime(value), getTransformed)
        end

        return nil
    end

    for key, value in pairs(input) do
        result[key] = getTransformed(value) or value
    end

    return result :: transform<T>
end

module.transform = function<T>(input: T) : transform<T>
    return transformRuntime(input)
end

return module
