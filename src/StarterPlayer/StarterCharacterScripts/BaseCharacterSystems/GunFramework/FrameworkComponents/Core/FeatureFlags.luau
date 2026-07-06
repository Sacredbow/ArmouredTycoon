--!strict

--[[
	FeatureFlags

	Central switches for ACS features that are being removed, paused, or rewritten.
	This keeps compatibility paths easy to find without deleting useful future work.

	Current direction:
		- guns stay active
		- melee/knife stays active
		- grenades are paused for a later dedicated grenade system
		- utility gear like breachers/medkits/lasers is disabled unless revived
]]

return {
	GunsEnabled = true,
	MeleeEnabled = true,
	GrenadesEnabled = false,
	WeaponUtilitiesEnabled = false,
}
