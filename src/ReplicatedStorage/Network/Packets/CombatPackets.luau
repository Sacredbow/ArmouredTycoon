--!strict

return function(ByteNet: any)
	return {
		WeaponState = ByteNet.definePacket({
			value = ByteNet.struct({
				["type"] = ByteNet.string,
				weaponName = ByteNet.optional(ByteNet.string),
				stance = ByteNet.optional(ByteNet.int32),
				lean = ByteNet.optional(ByteNet.int32),
			}),
		}),
	}
end
