--!strict

--[[
	WeaponUIState

	Publishes ACS weapon UI state into ClientRuntimeState. React components can
	subscribe to the table-backed state without depending on ACS internals or
	Player attributes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientRuntimeState = require(ReplicatedStorage.Shared.Game.Combat.ClientRuntimeState)

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

function WeaponUIState.clear(player: Player)
	ClientRuntimeState.ClearWeaponState(player)
end

function WeaponUIState.setAiming(player: Player, isAiming: boolean)
	ClientRuntimeState.SetWeaponAiming(player, isAiming)
end

function WeaponUIState.publishCrosshair(player: Player, info: CrosshairInfo)
	ClientRuntimeState.SetWeaponState(player, {
		CrosshairVisible = info.visible,
		CrosshairKind = info.kind,
		CrosshairMode = info.mode,
	})
end

function WeaponUIState.publishHud(
	player: Player,
	weaponData: WeaponData?,
	ammo: number?,
	storedAmmo: number?,
	safeMode: boolean,
	shootType: number?,
	jammed: boolean?
)
	if not weaponData or weaponData.Type ~= "Gun" then
		WeaponUIState.clear(player)
		return
	end

	local maxAmmo = math.max(read(weaponData.Ammo, 0), 0)
	local currentAmmo = math.max(read(ammo, read(weaponData.AmmoInGun, maxAmmo)), 0)
	local reserveAmmo = math.max(read(storedAmmo, read(weaponData.StoredAmmo, 0)), 0)
	local magazines = if read(weaponData.MagCount, false) and maxAmmo > 0
		then countMagazines(reserveAmmo, maxAmmo)
		else reserveAmmo
	local zeroText = if read(weaponData.EnableZeroing, false) then `{read(weaponData.CurrentZero, 0)} m` else "0 m"

	ClientRuntimeState.SetWeaponState(player, {
		WeaponEquipped = true,
		WeaponName = read(weaponData.gunName, "Weapon"),
		Ammo = currentAmmo,
		StoredAmmo = reserveAmmo,
		MaxAmmo = maxAmmo,
		Magazines = magazines,
		Firemode = FIREMODE_NAMES[read(shootType, read(weaponData.ShootType, 1))] or "Semi",
		BulletType = read(weaponData.BulletType, ""),
		WeaponJammed = read(jammed, read(weaponData.Jammed, false)),
		WeaponSafe = safeMode,
		ZeroText = zeroText,
	})
end

return WeaponUIState
