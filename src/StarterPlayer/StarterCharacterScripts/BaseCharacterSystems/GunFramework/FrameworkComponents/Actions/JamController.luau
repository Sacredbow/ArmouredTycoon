--!strict

--[[
	JamController

	Keeps jam probability and clearability rules out of Main.luau. The controller
	does not play animations or sounds; it only answers whether a jam happens or
	whether the current jam can be cleared.
]]

local JamController = {}

export type WeaponData = {
	Type: string?,
	CanBreak: boolean?,
	Jammed: boolean?,
}

export type AmmoState = {
	ammo: number,
}

local function isEnabled<T>(value: T?): boolean
	-- Authored ACS settings use optional booleans heavily; this narrows only true.
	return value == true
end

function JamController.roll(weaponData: WeaponData?, state: AmmoState, randomRoll: (number) -> number): boolean
	if not weaponData or not isEnabled(weaponData.CanBreak) or weaponData.Jammed or state.ammo - 1 <= 0 then
		return false
	end

	if randomRoll(1000) > 2 then
		return false
	end

	weaponData.Jammed = true
	return true
end

function JamController.canClear(weaponData: WeaponData?): boolean
	return weaponData ~= nil and weaponData.Type == "Gun" and weaponData.Jammed == true
end

return JamController
