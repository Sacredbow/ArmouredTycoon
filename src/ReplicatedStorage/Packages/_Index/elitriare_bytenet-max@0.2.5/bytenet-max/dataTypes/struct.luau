local RunService = game:GetService("RunService")

local namespacesDependencies = require(script.Parent.Parent.namespaces.namespaceDependencies)
local values = require(script.Parent.Parent.replicated.values)
local types = require(script.Parent.Parent.types)

local runContext: "server" | "client" = if RunService:IsServer() then "server" else "client"

type structData = {
	[string]: number,
}

local function getSortedKeys(input: { [string]: types.dataTypeInterface<any> }): { string }
	local keys = {}
	for key in input do
		table.insert(keys, key)
	end

	table.sort(keys)
	return keys
end

local function serializeInput(input: { [string]: types.dataTypeInterface<any> }): structData
	local serializedStruct = {}
	for index, key in ipairs(getSortedKeys(input)) do
		serializedStruct[key] = index
	end

	return serializedStruct
end

return function(input: {
	[string]: types.dataTypeInterface<any>,
}): types.dataTypeInterface<any>
	-- This is used in the reading/writing parts, and isn't used in the initialization code
	-- It's used to store the index-value pairs and the index-key pairs
	-- Index being the position of the value in the array, and the key being the key in the struct dictionary
	local indexValueTypePairs: {
		[number]: types.dataTypeInterface<any>,
	} = {}
	local indexKeyPairs: { [number]: string } = {}

	--[[
		Array should look like {
			[index (1)] = value
			[index (2)] = value
		}

		Index value type is {
			[index (1)] = int32
		}

		Index key is {
			[index (1)] = "structField"
		}
	]]

	if runContext == "server" then
		local serializedStruct = serializeInput(input)
		for key, index in serializedStruct do
			-- Store the index-value pairs and the index-key pairs as a shortcut for serializing n all that
			indexValueTypePairs[index] = input[key]
			indexKeyPairs[index] = key
		end

		-- replicate
		namespacesDependencies.add(serializedStruct)
	elseif runContext == "client" then
		-- There's a layer of complexity added here because we have to access the namespace data
		namespacesDependencies.add(input)

		local name = namespacesDependencies.currentName()

		local namespaceReplicator = values.access(name)
		local namespaceData = if namespaceReplicator then namespaceReplicator:read() :: types.namespaceData else nil

		-- struct id is just based on the order of creation in the namespace function
		local structData = if namespaceData and namespaceData.structs
			then namespaceData.structs[namespacesDependencies.currentLength()] or serializeInput(input)
			else serializeInput(input)

		-- Fetch the data from the server and store it in the index-value pairs and the index-key pairs
		for key, index in structData do
			local valueType = input[key]
			if valueType then
				indexValueTypePairs[index] = valueType
				indexKeyPairs[index] = key
			end
		end
	end

	return {
		read = function(b, cursor)
			local constructed = table.clone(input)
			local structCursor = cursor

			for index, valueType in indexValueTypePairs do
				local value, length = valueType.read(b, structCursor)

				constructed[indexKeyPairs[index]] = value

				structCursor += length
			end

			return constructed, structCursor - cursor
		end,

		write = function(structValue)
			for index, valueType in indexValueTypePairs do
				valueType.write(structValue[indexKeyPairs[index]])
			end
		end,
	}
end
