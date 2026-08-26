--!strict

return function(ByteNet: any)
	return {
		NPCConversation = ByteNet.definePacket({
			value = ByteNet.struct({
				action = ByteNet.string,
				conversationId = ByteNet.optional(ByteNet.string),
				npcName = ByteNet.optional(ByteNet.string),
				npcLine = ByteNet.optional(ByteNet.string),
				turnCount = ByteNet.optional(ByteNet.int8),
				maxTurns = ByteNet.optional(ByteNet.int8),
				reason = ByteNet.optional(ByteNet.string),
				options = ByteNet.optional(ByteNet.array(ByteNet.struct({
					id = ByteNet.string,
					text = ByteNet.string,
					tone = ByteNet.string,
				}))),
			}),
		}),

		NPCConversationChoice = ByteNet.definePacket({
			value = ByteNet.struct({
				action = ByteNet.string,
				conversationId = ByteNet.string,
				optionId = ByteNet.optional(ByteNet.string),
			}),
		}),

		NPCSpeech = ByteNet.definePacket({
			value = ByteNet.struct({
				adornee = ByteNet.inst,
				message = ByteNet.string,
			}),
		}),
	}
end