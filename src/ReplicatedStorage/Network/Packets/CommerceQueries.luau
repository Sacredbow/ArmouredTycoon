--!strict

return function(ByteNet: any)
	local actionResponse = ByteNet.struct({
		success = ByteNet.bool,
		message = ByteNet.string,
	})

	local actionRequest = ByteNet.struct({
		action = ByteNet.string,
		payload = ByteNet.optional(ByteNet.string),
	})

	return {
		RedeemCode = ByteNet.defineQuery({
			request = ByteNet.struct({
				code = ByteNet.string,
			}),
			response = actionResponse,
		}),

		ProfileAction = ByteNet.defineQuery({
			request = actionRequest,
			response = actionResponse,
		}),

		TycoonAction = ByteNet.defineQuery({
			request = actionRequest,
			response = actionResponse,
		}),
	}
end
