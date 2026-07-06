--!strict

--[[
	FiremodeController

	Small state machine for cycling ACS fire modes. It mutates WeaponData because
	the old framework stores the active mode directly on the settings table and
	other parts of Main read that value.
]]

local FiremodeController = {}

export type FireModes = {
	ChangeFiremode: boolean?,
	Semi: boolean?,
	Burst: boolean?,
	Auto: boolean?,
}

export type WeaponData = {
	ShootType: number,
	FireModes: FireModes,
}

local function bool<T>(value: T?, fallback: boolean): boolean
	-- Config modules sometimes omit mode flags. Treat missing values as the
	-- provided fallback instead of making every caller repeat nil checks.
	if typeof(value) == "boolean" then
		return value :: any
	end

	return fallback
end

function FiremodeController.nextShootType(weaponData: WeaponData): number
	local shootType = weaponData.ShootType
	local modes = weaponData.FireModes

	if shootType == 1 and bool(modes.Burst, false) then
		return 2
	end

	if shootType == 1 and not bool(modes.Burst, false) and bool(modes.Auto, false) then
		return 3
	end

	if shootType == 2 and bool(modes.Auto, false) then
		return 3
	end

	if shootType == 2 and bool(modes.Semi, false) and not bool(modes.Auto, false) then
		return 1
	end

	if shootType == 3 and bool(modes.Semi, false) then
		return 1
	end

	if shootType == 3 and not bool(modes.Semi, false) and bool(modes.Burst, false) then
		return 2
	end

	return shootType
end

function FiremodeController.cycle(weaponData: WeaponData): boolean
	local nextType = FiremodeController.nextShootType(weaponData)
	local changed = nextType ~= weaponData.ShootType
	weaponData.ShootType = nextType
	return changed
end

return FiremodeController
