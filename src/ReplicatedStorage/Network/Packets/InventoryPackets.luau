--!strict

return function(ByteNet: any)
	return {
		InventoryAction = ByteNet.definePacket({
			value = ByteNet.struct({
				action = ByteNet.string,
				tool = ByteNet.optional(ByteNet.inst),
			}),
		}),
	}
end