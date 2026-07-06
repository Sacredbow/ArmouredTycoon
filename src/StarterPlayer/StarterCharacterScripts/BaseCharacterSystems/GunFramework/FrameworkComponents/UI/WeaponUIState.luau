--!strict

--[[
	WeaponUIState

	Publishes weapon state as Player attributes. React components and other client
	UI can subscribe to these attributes without depending on ACS internals.

	This is the bridge between old ACS state and the newer UI direction: Main still
	uses SE_GUI for the weapon HUD, but crosshair and future panels can read these
	attributes cleanly.
]]

local WeaponUIState = {}

export type WeaponData = {
	Type: string?,
	gunName: string?,
	Ammo: number?,
	AmmoInGun: number?,
	StoredAmmo: number?,
	BulletType: string?,
	ShootType: number?,
	MagCount: boolean?,
	Jammed: boolean?,
	EnableZeroing: boolean?,
	CurrentZero: number?,
	Bullets: number?,
}

export type CrosshairInfo = {
	visible: boolean,
	kind: string,
	mode: string,
}

local FIREMODE_NAMES = {
	[1] = "Semi",
	[2] = "Burst",
	[3] = "Auto",
	[4] = "Pump",
	[5] = "Bolt",
}

local function read<T>(value: T?, fallback: T): T
	-- Generic fallback helper for weapon config values that may be absent.
	if value == nil then
		return fallback
	end

	return value
end

local function countMagazines(storedAmmo: number, ammoPerMagazine: number): number
	if ammoPerMagazine <= 0 or storedAmmo <= 0 then
		return 0
	end

	return math.ceil(storedAmmo / ammoPerMagazine)
end
local function setAttribute<T>(player: Player, name: string, value: T)
	-- Attribute writes are the stable boundary between ACS and React UI.
	player:SetAttribute(name, value :: any)
end

function WeaponUIState.clear(player: Player)
	-- Clear everything on unequip so React UI does not show stale weapon data.
	setAttribute(player, "ACS_WeaponEquipped", false)
	setAttribute(player, "ACS_CrosshairVisible", false)
	setAttribute(player, "ACS_CrosshairKind", "none")
	setAttribute(player, "ACS_WeaponName", "")
	setAttribute(player, "ACS_Ammo", 0)
	setAttribute(player, "ACS_StoredAmmo", 0)
	setAttribute(player, "ACS_MaxAmmo", 0)
	setAttribute(player, "ACS_Magazines", 0)
	setAttribute(player, "ACS_Firemode", "")
	setAttribute(player, "ACS_BulletType", "")
	setAttribute(player, "ACS_WeaponJammed", false)
	setAttribute(player, "ACS_WeaponSafe", false)
	setAttribute(player, "ACS_ZeroText", "")
end

function WeaponUIState.publishCrosshair(player: Player, info: CrosshairInfo)
	-- Crosshair is separate from the weapon HUD so third-person/first-person modes
	-- can change without touching old SE_GUI objects.
	setAttribute(player, "ACS_CrosshairVisible", info.visible)
	setAttribute(player, "ACS_CrosshairKind", info.kind)
	setAttribute(player, "ACS_CrosshairMode", info.mode)
end

function WeaponUIState.publishHud(player: Player, weaponData: WeaponData?, ammo: number?, storedAmmo: number?, safeMode: boolean)
	-- Main calls this whenever weapon HUD state changes. Attribute updates are
	-- intentionally simple primitives so UI consumers stay decoupled from ACS.
	if not weaponData or weaponData.Type ~= "Gun" then
		WeaponUIState.clear(player)
		return
	end

	local maxAmmo = math.max(read(weaponData.Ammo, 0), 0)
	local currentAmmo = math.max(read(ammo, read(weaponData.AmmoInGun, maxAmmo)), 0)
	local reserveAmmo = math.max(read(storedAmmo, read(weaponData.StoredAmmo, 0)), 0)
	local magazines = if read(weaponData.MagCount, false) and maxAmmo > 0 then countMagazines(reserveAmmo, maxAmmo) else reserveAmmo
	local zeroText = if read(weaponData.EnableZeroing, false) then `{read(weaponData.CurrentZero, 0)} m` else "0 m"

	setAttribute(player, "ACS_WeaponEquipped", true)
	setAttribute(player, "ACS_WeaponName", read(weaponData.gunName, "Weapon"))
	setAttribute(player, "ACS_Ammo", currentAmmo)
	setAttribute(player, "ACS_StoredAmmo", reserveAmmo)
	setAttribute(player, "ACS_MaxAmmo", maxAmmo)
	setAttribute(player, "ACS_Magazines", magazines)
	setAttribute(player, "ACS_Firemode", FIREMODE_NAMES[read(weaponData.ShootType, 1)] or "Semi")
	setAttribute(player, "ACS_BulletType", read(weaponData.BulletType, ""))
	setAttribute(player, "ACS_WeaponJammed", read(weaponData.Jammed, false))
	setAttribute(player, "ACS_WeaponSafe", safeMode)
	setAttribute(player, "ACS_ZeroText", zeroText)
end

return WeaponUIState
