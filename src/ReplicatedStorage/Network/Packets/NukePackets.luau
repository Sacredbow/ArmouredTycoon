--!strict

return function(ByteNet: any)
	return {
		NukeCinematic = ByteNet.definePacket({
			value = ByteNet.struct({
				action = ByteNet.string,
				sessionId = ByteNet.optional(ByteNet.string),
				role = ByteNet.optional(ByteNet.string),
				phase = ByteNet.optional(ByteNet.string),
				message = ByteNet.optional(ByteNet.string),
				launcherName = ByteNet.optional(ByteNet.string),
				defenderName = ByteNet.optional(ByteNet.string),
				launcherUserId = ByteNet.optional(ByteNet.string),
				defenderUserId = ByteNet.optional(ByteNet.string),
				winnerName = ByteNet.optional(ByteNet.string),
				targetPosition = ByteNet.optional(ByteNet.vec3),
				sourcePosition = ByteNet.optional(ByteNet.vec3),
				distance = ByteNet.optional(ByteNet.float32),
				deathRange = ByteNet.optional(ByteNet.float32),
				timeLeft = ByteNet.optional(ByteNet.float32),
				launcherScore = ByteNet.optional(ByteNet.int32),
				defenderScore = ByteNet.optional(ByteNet.int32),
			}),
		}),

		NukeScore = ByteNet.definePacket({
			value = ByteNet.struct({
				sessionId = ByteNet.string,
				launcherScore = ByteNet.int32,
				defenderScore = ByteNet.int32,
			}),
		}),

		NukeClickBatch = ByteNet.definePacket({
			value = ByteNet.struct({
				sessionId = ByteNet.string,
				count = ByteNet.int32,
				clientWindow = ByteNet.float32,
			}),
		}),
	}
end
