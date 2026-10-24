--[[
    TODO
    update ancestor tables on generic value change
]]

local number = require("@self/fields/number")
local string = require("@self/fields/string")
local array = require("@self/fields/array")
local dict = require("@self/fields/dict")

type stringClassType = string.classType
type numberClassType = number.classType
type function dictClassType(T: type, U: type, V: type): type
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

    addMethod("Get", {result, T}, {U})
    addMethod("Set", {result, T, V}, {U})

    return result
end
type function arrayClassType(T: type, U: type): type
    local result = types.newtable()

    result:setproperty(types.singleton("_table"), types.newtable(nil, {
        index = types.number,
        readresult = T,
        writeresult = T,
    }))

    result:setproperty(types.singleton("_transform"), types.newfunction(
        {head = {U}},
        {head = {T}}
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

    local optionalNumber = types.optional(types.number)

    addMethod("Get", {result, types.number}, {T})
    addMethod("Insert", {result, U, optionalNumber}, {T})
    addMethod("Remove", {result, types.number}, {types.optional(T)})
    addMethod("Find", {result, T, optionalNumber}, {optionalNumber})

    return result
end

type arrayMT = {__index : {type : "array"}}
type dictMT = {__index : {type : "dict"}}
type arrayType<T> = setmetatable<T, arrayMT>
type dictType<T> = setmetatable<T, dictMT>

export type function transformSchema(schema : type) : type
    assert(schema:is("table"), "expected a table type")

    local function getTransformed(type : type) : type
        local indexer = type:readindexer()

        if indexer then
            if indexer.result:is("table") then
                type:setindexer(
                    indexer.index,
                    getTransformed(indexer.result)
                )
            end

            if indexer.index:is("number") then
                return arrayType(type)
            else
                return dictType(type)
            end
        else
            return transformSchema(type)
        end
    end

	for key, value in schema:properties() do
		if value.read then
			if value.read:is("table") then
                schema:setproperty(key, getTransformed(value.read))
            end
		end
	end

    return schema
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
                    return arrayClassType(
                        getTransformed(indexer.result),
                        indexer.result
                    )
                else
                    return dictClassType(
                        indexer.index,
                        getTransformed(indexer.result),
                        indexer.result
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
            local mt : (arrayMT | dictMT)? = getmetatable(value)

            if mt then
                if mt.__index.type == "dict" then
                    return dict.new(transformRuntime(value), getTransformed)
                elseif mt.__index.type == "array" then
                    return array.new(transformRuntime(value), getTransformed)
                end
            end
        end

        return nil
    end

    for key, value in pairs(input) do
        result[key] = getTransformed(value) or value
    end

    return result :: transform<T>
end

module.array = function<T>(table_ : T) : arrayType<T>
    local mt : arrayMT = {
        __index = {type = "array"}
    }
    
    return setmetatable(table_, mt) :: arrayType<T>
end

module.dict = function<T>(table_ : T) : dictType<T>
    local mt : dictMT = {
        __index = {type = "dict"}
    }

    return setmetatable(table_, mt) :: dictType<T>
end

module.transform = function<T>(input: T) : transform<T>
    return transformRuntime(input)
end

return module
