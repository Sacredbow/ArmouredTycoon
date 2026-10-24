--!strict

return function(ByteNet: any)
	return {
		ProjectileIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				origin = ByteNet.vec3,
				direction = ByteNet.vec3,
				muzzleVelocity = ByteNet.float32,
			}),
			reliabilityType = "unreliable",
		}),

		ProjectilePresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				shooterUserId = ByteNet.uint32,
				origin = ByteNet.vec3,
				direction = ByteNet.vec3,
				tracer = ByteNet.bool,
				bulletFlare = ByteNet.bool,
				tracerColor = ByteNet.color3,
				muzzleVelocity = ByteNet.float32,
			}),
			reliabilityType = "unreliable",
		}),

		WeaponFireIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.inst,
			}),
			reliabilityType = "unreliable",
		}),

		WeaponFirePresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				shooterUserId = ByteNet.uint32,
				weapon = ByteNet.inst,
				suppressor = ByteNet.bool,
				flashHider = ByteNet.bool,
			}),
			reliabilityType = "unreliable",
		}),

		WhizzIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				victim = ByteNet.inst,
			}),
			reliabilityType = "unreliable",
		}),

		WhizzPresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				shooterUserId = ByteNet.uint32,
			}),
			reliabilityType = "unreliable",
		}),

		SuppressionIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				victim = ByteNet.inst,
				mode = ByteNet.int8,
				intensity = ByteNet.optional(ByteNet.float32),
				time = ByteNet.optional(ByteNet.float32),
			}),
			reliabilityType = "unreliable",
		}),

		SuppressionPresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				mode = ByteNet.int8,
				intensity = ByteNet.float32,
				duration = ByteNet.float32,
			}),
			reliabilityType = "unreliable",
		}),

		HitEffectIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				position = ByteNet.vec3,
				hitPart = ByteNet.inst,
				normal = ByteNet.vec3,
				material = ByteNet.string,
			}),
			reliabilityType = "unreliable",
		}),

		HitEffectPresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				shooterUserId = ByteNet.uint32,
				weapon = ByteNet.inst,
				position = ByteNet.vec3,
				hitPart = ByteNet.inst,
				normal = ByteNet.vec3,
				material = ByteNet.string,
			}),
			reliabilityType = "unreliable",
		}),

		LaserIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				position = ByteNet.optional(ByteNet.vec3),
				mode = ByteNet.int8,
				color = ByteNet.optional(ByteNet.color3),
				infrared = ByteNet.bool,
				weapon = ByteNet.inst,
			}),
			reliabilityType = "unreliable",
		}),

		LaserPresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				shooterUserId = ByteNet.uint32,
				position = ByteNet.optional(ByteNet.vec3),
				mode = ByteNet.int8,
				color = ByteNet.optional(ByteNet.color3),
				infrared = ByteNet.bool,
				weapon = ByteNet.inst,
			}),
			reliabilityType = "unreliable",
		}),

		FlashIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.inst,
				enabled = ByteNet.bool,
			}),
			reliabilityType = "unreliable",
		}),

		FlashPresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				shooterUserId = ByteNet.uint32,
				weapon = ByteNet.inst,
				enabled = ByteNet.bool,
			}),
			reliabilityType = "unreliable",
		}),

		GunStanceIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				stance = ByteNet.int8,
			}),
			reliabilityType = "unreliable",
		}),

		GunStancePresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				shooterUserId = ByteNet.uint32,
				stance = ByteNet.int8,
			}),
			reliabilityType = "unreliable",
		}),
		EquipIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.inst,
				mode = ByteNet.int8,
			}),
		}),

		ShieldHitIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				shield = ByteNet.inst,
			}),
			reliabilityType = "unreliable",
		}),

		DamageIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.inst,
				targetHumanoid = ByteNet.inst,
				hitPart = ByteNet.inst,
				hitType = ByteNet.int8,
			}),
		}),

		StanceIntent = ByteNet.definePacket({
			value = ByteNet.struct({
				stance = ByteNet.int8,
				lean = ByteNet.float32,
			}),
			reliabilityType = "unreliable",
		}),
		RefillPresentation = ByteNet.definePacket({
			value = ByteNet.struct({
				tool = ByteNet.inst,
				infinite = ByteNet.bool,
				amount = ByteNet.float32,
			}),
		}),
	}
end
