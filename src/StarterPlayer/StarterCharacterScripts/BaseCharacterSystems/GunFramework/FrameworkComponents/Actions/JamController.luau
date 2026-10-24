--!strict

local JamController = {}

export type WeaponData = {
	Type: string?,
	CanBreak: boolean?,
}

export type AmmoState = {
	ammo: number,
}

local function isEnabled<T>(value: T?): boolean
	return value == true
end

function JamController.roll(
	weaponData: WeaponData?,
	currentJammed: boolean,
	state: AmmoState,
	randomRoll: (number) -> number
): boolean
	if not weaponData or not isEnabled(weaponData.CanBreak) or currentJammed or state.ammo - 1 <= 0 then
		return false
	end

	if randomRoll(1000) > 2 then
		return false
	end

	return true
end

function JamController.canClear(weaponData: WeaponData?, currentJammed: boolean): boolean
	return weaponData ~= nil and weaponData.Type == "Gun" and currentJammed
end

return JamController
