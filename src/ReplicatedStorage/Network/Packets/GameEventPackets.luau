--!strict

export type GameEventType = "NotFollowing" | "Prompt" | "SystemMessage" | "CanRebirth"

return function(ByteNet: any)
	return {
		GameEvent = ByteNet.definePacket({
			value = ByteNet.struct({
				type = ByteNet.string,
				message = ByteNet.optional(ByteNet.string),
				valueBoolean = ByteNet.optional(ByteNet.bool),
				valueNumber = ByteNet.optional(ByteNet.float32),
				valueString = ByteNet.optional(ByteNet.string),
				amount = ByteNet.optional(ByteNet.float32),
				position = ByteNet.optional(ByteNet.vec3),
			}),
		}),

		CashCollected = ByteNet.definePacket({
			value = ByteNet.struct({
				amount = ByteNet.float32,
				origin = ByteNet.vec3,
			}),
		}),
	}
end
