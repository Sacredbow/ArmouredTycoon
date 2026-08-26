--!strict

export type TutorialType =
	"TycoonClaimed"
	| "TycoonAvailable"
	| "Perfect!"
	| "Now purchase your first button!"
	| "Claim your money"
	| "Congrats! Tutorial Completed."

return function(ByteNet: any)
	return {
		Notification = ByteNet.definePacket({
			value = ByteNet.struct({
				type = ByteNet.string,
				message = ByteNet.optional(ByteNet.string),
				duration = ByteNet.optional(ByteNet.float32),
			}),
		}),

		Tutorial = ByteNet.definePacket({
			value = ByteNet.struct({
				type = ByteNet.string,
				target = ByteNet.optional(ByteNet.string),
			}),
		}),
	}
end
