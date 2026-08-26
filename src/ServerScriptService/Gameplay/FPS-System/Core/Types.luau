--!strict
--[[
	@class FPSTypes

	@desc
	Shared type definitions for the server-side FPS combat engine (ACS).
	These mirror the weapon settings tables defined per-gun in ACS_Settings
	modules and validated at runtime by FPSSecurity.
]]

export type WeaponSettings = {
	gunName: string,
	Type: string,
	ShootRate: number,
	Bullets: number,
	LimbDamage: { number },
	TorsoDamage: { number },
	HeadDamage: { number },

	-- Optional fields (absent on some weapons)
	MinDamage: number?,
	DamageFallOf: number?,
	BulletPenetration: number?,
	IgnoreProtection: boolean?,
	SightAtt: string?,
	BarrelAtt: string?,
	UnderBarrelAtt: string?,
	OtherAtt: string?,
}

export type ModifierSettings = {
	DamageMod: number?,
	minDamageMod: number?,
}

return {}

