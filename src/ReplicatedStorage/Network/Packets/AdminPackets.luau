--!strict

return function(ByteNet: any)
	return {
		AdminUiReady = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
	}
end