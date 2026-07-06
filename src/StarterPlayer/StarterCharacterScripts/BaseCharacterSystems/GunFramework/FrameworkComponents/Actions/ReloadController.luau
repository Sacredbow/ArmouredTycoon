--!strict

--[[
	ReloadController

	Owns ammo arithmetic for magazine and shell-by-shell reloads. Animations,
	delays, cancellation, and HUD updates stay in Main for now, while this module
	keeps the actual count transitions consistent.
]]

local ReloadController = {}

export type WeaponData = {
	Type: string?,
	Ammo: number,
	IncludeChamberedBullet: boolean?,
	ShellInsert: boolean?,
}

export type AmmoState = {
	ammo: number,
	storedAmmo: number,
}

local function min<T>(value: T?, fallback: T): T
	-- Generic helper for config defaults. Some ACS weapons omit max ammo values.
	if value == nil then
		return fallback
	end

	return value
end

function ReloadController.canReload(weaponData: WeaponData?, state: AmmoState): boolean
	if not weaponData or weaponData.Type ~= "Gun" or state.storedAmmo <= 0 then
		return false
	end

	local maxLoaded = weaponData.Ammo
	if min(weaponData.IncludeChamberedBullet, false) then
		maxLoaded += 1
	end

	return state.ammo < maxLoaded
end

function ReloadController.finishMagazineReload(weaponData: WeaponData, state: AmmoState): AmmoState
	local ammo = state.ammo
	local storedAmmo = state.storedAmmo
	local missing = weaponData.Ammo - ammo

	if storedAmmo < missing then
		ammo += storedAmmo
		storedAmmo = 0
	elseif ammo > 0 and min(weaponData.IncludeChamberedBullet, false) then
		storedAmmo -= missing + 1
		ammo = weaponData.Ammo + 1
	else
		storedAmmo -= missing
		ammo = weaponData.Ammo
	end

	return {
		ammo = math.max(ammo, 0),
		storedAmmo = math.max(storedAmmo, 0),
	}
end

function ReloadController.insertOne(state: AmmoState): AmmoState
	if state.storedAmmo <= 0 then
		return state
	end

	return {
		ammo = state.ammo + 1,
		storedAmmo = state.storedAmmo - 1,
	}
end

return ReloadController

