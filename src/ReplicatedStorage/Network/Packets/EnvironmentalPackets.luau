--!strict

return function(ByteNet: any)
	return {
		Weather = ByteNet.definePacket({
			value = ByteNet.struct({
				["type"] = ByteNet.string,
				duration = ByteNet.float32,
				windDirection = ByteNet.vec3,
				windSpeed = ByteNet.float32,
				windPower = ByteNet.float32,
				rainIntensity = ByteNet.float32,
				thunderChance = ByteNet.float32,
				lightingWeight = ByteNet.float32,
			}),
		}),

		WeatherChanged = ByteNet.definePacket({
			value = ByteNet.struct({
				weatherId = ByteNet.string,
				displayName = ByteNet.string,
				duration = ByteNet.float32,
			}),
		}),

		ShootingStar = ByteNet.definePacket({
			value = ByteNet.struct({
				startPosition = ByteNet.vec3,
				direction = ByteNet.vec3,
				impact = ByteNet.boolean,
			}),
		}),

		LightningStrike = ByteNet.definePacket({
			value = ByteNet.struct({
				startPosition = ByteNet.vec3,
				endPosition = ByteNet.vec3,
				seed = ByteNet.int32,
			}),
			reliabilityType = "unreliable",
		}),
	}
end
