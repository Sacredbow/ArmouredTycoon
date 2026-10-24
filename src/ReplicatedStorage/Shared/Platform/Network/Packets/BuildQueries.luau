--!strict

return function(ByteNet: any)
	local buildState = ByteNet.struct({
		cellSize = ByteNet.int32,
		width = ByteNet.int32,
		height = ByteNet.int32,
		origin = ByteNet.cframe,
		compoundSize = ByteNet.vec3,
		occupied = ByteNet.string,
	})

	local actionResponse = ByteNet.struct({
		success = ByteNet.bool,
		message = ByteNet.string,
		state = ByteNet.optional(buildState),
		payload = ByteNet.optional(ByteNet.string),
	})

	return {
		BuildAction = ByteNet.defineQuery({
			request = ByteNet.struct({
				action = ByteNet.string,
				payload = ByteNet.optional(ByteNet.string),
			}),
			response = actionResponse,
		}),
	}
end
