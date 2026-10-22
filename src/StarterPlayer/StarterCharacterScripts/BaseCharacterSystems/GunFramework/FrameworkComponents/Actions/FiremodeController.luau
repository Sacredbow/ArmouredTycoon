--!strict

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
	if typeof(value) == "boolean" then
		return value :: any
	end

	return fallback
end

function FiremodeController.nextShootType(weaponData: WeaponData, currentShootType: number?): number
	local shootType = currentShootType or weaponData.ShootType
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

function FiremodeController.cycle(weaponData: WeaponData, currentShootType: number): (boolean, number)
	local nextType = FiremodeController.nextShootType(weaponData, currentShootType)
	return nextType ~= currentShootType, nextType
end

return FiremodeController
