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

		BuildAssemble = ByteNet.definePacket({
			value = ByteNet.struct({
				item = ByteNet.inst,
				duration = ByteNet.optional(ByteNet.float32),
				mode = ByteNet.optional(ByteNet.string),
			}),
		}),

		DropperVisual = ByteNet.definePacket({
			value = ByteNet.struct({
				dropper = ByteNet.inst,
				spawnPart = ByteNet.inst,
			}),
			reliabilityType = "unreliable",
		}),
	}
end
