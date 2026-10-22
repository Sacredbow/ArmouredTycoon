--!strict

return function(ByteNet: any)
	return {
		SettingsAction = ByteNet.defineQuery({
			request = ByteNet.struct({
				action = ByteNet.string,
				payload = ByteNet.optional(ByteNet.string),
			}),
			response = ByteNet.struct({
				success = ByteNet.bool,
				message = ByteNet.string,
				payload = ByteNet.optional(ByteNet.string),
			}),
		}),
	}
end