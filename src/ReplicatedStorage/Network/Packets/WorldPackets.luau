--!strict

return function(ByteNet: any)
	return {
		KOTHAnnouncement = ByteNet.definePacket({
			value = ByteNet.struct({
				playerName = ByteNet.string,
				teamColor = ByteNet.color3,
				minutes = ByteNet.optional(ByteNet.int32),
			}),
		}),
	}
end
