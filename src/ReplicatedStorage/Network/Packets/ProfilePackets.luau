--!strict

return function(ByteNet: any)
	return {
		ProfileState = ByteNet.definePacket({
			value = ByteNet.struct({
				payload = ByteNet.string,
			}),
		}),

		StatSync = ByteNet.definePacket({
			value = ByteNet.struct({
				stat = ByteNet.string,
				value = ByteNet.int32,
			}),
		}),

		FriendBoost = ByteNet.definePacket({
			value = ByteNet.struct({
				["type"] = ByteNet.string,
				percent = ByteNet.float32,
			}),
		}),
	}
end
