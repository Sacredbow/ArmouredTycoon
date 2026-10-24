--!strict

--[[
	AttachmentModifiers

	Stores cumulative multipliers from weapon attachments. Main keeps one
	ModTable per equipped weapon, then every attachment multiplies into it.

	Most values default to 1 because they are multipliers. Zoom defaults remain
	70 to match the old ACS camera behavior before weapon-specific zoom is copied
	in during setup.
]]

local AttachmentModifiers = {}

function AttachmentModifiers.createDefault(): any
	-- Keep this table shape stable. Damage, recoil, spread, and projectile code
	-- expect these keys to exist even when no attachments are installed.
	return {
		camRecoilMod = {
			RecoilTilt = 1,
			RecoilUp = 1,
			RecoilLeft = 1,
			RecoilRight = 1,
		},
		gunRecoilMod = {
			RecoilUp = 1,
			RecoilTilt = 1,
			RecoilLeft = 1,
			RecoilRight = 1,
		},
		ZoomValue = 70,
		Zoom2Value = 70,
		AimRM = 1,
		SpreadRM = 1,
		DamageMod = 1,
		minDamageMod = 1,
		MinRecoilPower = 1,
		MaxRecoilPower = 1,
		RecoilPowerStepAmount = 1,
		MinSpread = 1,
		MaxSpread = 1,
		AimInaccuracyStepAmount = 1,
		AimInaccuracyDecrease = 1,
		WalkMult = 1,
		adsTime = 1,
		MuzzleVelocity = 1,
	}
end

function AttachmentModifiers.reset(modifierTable: any)
	-- Mutate the existing table instead of replacing it, because Main and effect
	-- callbacks may already hold references to this table during equip.
	local defaultModifiers = AttachmentModifiers.createDefault()

	for key, value in defaultModifiers do
		if typeof(value) == "table" then
			for nestedKey, nestedValue in value do
				modifierTable[key][nestedKey] = nestedValue
			end
		else
			modifierTable[key] = value
		end
	end
end

function AttachmentModifiers.apply(modifierTable: any, modifierData: any)
	-- Attachment modules are authored as full multiplier packs. Multiplication
	-- allows multiple attachments to stack without needing special cases.
	modifierTable.camRecoilMod.RecoilUp *= modifierData.camRecoil.RecoilUp
	modifierTable.camRecoilMod.RecoilLeft *= modifierData.camRecoil.RecoilLeft
	modifierTable.camRecoilMod.RecoilRight *= modifierData.camRecoil.RecoilRight
	modifierTable.camRecoilMod.RecoilTilt *= modifierData.camRecoil.RecoilTilt

	modifierTable.gunRecoilMod.RecoilUp *= modifierData.gunRecoil.RecoilUp
	modifierTable.gunRecoilMod.RecoilTilt *= modifierData.gunRecoil.RecoilTilt
	modifierTable.gunRecoilMod.RecoilLeft *= modifierData.gunRecoil.RecoilLeft
	modifierTable.gunRecoilMod.RecoilRight *= modifierData.gunRecoil.RecoilRight

	modifierTable.AimRM *= modifierData.AimRecoilReduction
	modifierTable.SpreadRM *= modifierData.AimSpreadReduction
	modifierTable.DamageMod *= modifierData.DamageMod
	modifierTable.minDamageMod *= modifierData.minDamageMod
	modifierTable.MinRecoilPower *= modifierData.MinRecoilPower
	modifierTable.MaxRecoilPower *= modifierData.MaxRecoilPower
	modifierTable.RecoilPowerStepAmount *= modifierData.RecoilPowerStepAmount
	modifierTable.MinSpread *= modifierData.MinSpread
	modifierTable.MaxSpread *= modifierData.MaxSpread
	modifierTable.AimInaccuracyStepAmount *= modifierData.AimInaccuracyStepAmount
	modifierTable.AimInaccuracyDecrease *= modifierData.AimInaccuracyDecrease
	modifierTable.WalkMult *= modifierData.WalkMult
	modifierTable.MuzzleVelocity *= modifierData.MuzzleVelocityMod
end

return AttachmentModifiers
