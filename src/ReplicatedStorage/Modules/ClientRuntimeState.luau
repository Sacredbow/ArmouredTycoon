--!strict

export type PlayerState = {
	HasLoaded: boolean,
}

export type WeaponState = {
	WeaponEquipped: boolean,
	CrosshairVisible: boolean,
	CrosshairKind: string,
	CrosshairMode: string,
	Aiming: boolean,
	WeaponName: string,
	Ammo: number,
	StoredAmmo: number,
	MaxAmmo: number,
	Magazines: number,
	Firemode: string,
	BulletType: string,
	WeaponJammed: boolean,
	WeaponSafe: boolean,
	ZeroText: string,
}

local DEFAULT_STATE: PlayerState = {
	HasLoaded = false,
}

local DEFAULT_WEAPON_STATE: WeaponState = {
	WeaponEquipped = false,
	CrosshairVisible = false,
	CrosshairKind = "none",
	CrosshairMode = "first",
	Aiming = false,
	WeaponName = "",
	Ammo = 0,
	StoredAmmo = 0,
	MaxAmmo = 0,
	Magazines = 0,
	Firemode = "",
	BulletType = "",
	WeaponJammed = false,
	WeaponSafe = false,
	ZeroText = "",
}

local StatesByPlayer: { [Player]: PlayerState } = setmetatable({}, { __mode = "k" }) :: any
local WeaponStatesByPlayer: { [Player]: WeaponState } = setmetatable({}, { __mode = "k" }) :: any
local WeaponChanged = Instance.new("BindableEvent")

local ClientRuntimeState = {}

local function cloneDefaults(): PlayerState
	return table.clone(DEFAULT_STATE) :: PlayerState
end

local function cloneWeaponState(state: WeaponState): WeaponState
	return table.clone(state) :: WeaponState
end

function ClientRuntimeState.Get(player: Player): PlayerState
	local state = StatesByPlayer[player]
	if not state then
		state = cloneDefaults()
		StatesByPlayer[player] = state
	end

	return state
end

function ClientRuntimeState.SetHasLoaded(player: Player, value: boolean)
	ClientRuntimeState.Get(player).HasLoaded = value
end

function ClientRuntimeState.HasLoaded(player: Player): boolean
	return ClientRuntimeState.Get(player).HasLoaded
end

function ClientRuntimeState.GetWeaponState(player: Player): WeaponState
	local state = WeaponStatesByPlayer[player]
	if not state then
		state = cloneWeaponState(DEFAULT_WEAPON_STATE)
		WeaponStatesByPlayer[player] = state
	end

	return state
end

function ClientRuntimeState.ReadWeaponState(player: Player): WeaponState
	return cloneWeaponState(ClientRuntimeState.GetWeaponState(player))
end

function ClientRuntimeState.SetWeaponState(player: Player, patch: { [string]: any })
	local state = ClientRuntimeState.GetWeaponState(player) :: any
	for key, value in pairs(patch) do
		state[key] = value
	end

	WeaponChanged:Fire(player)
end

function ClientRuntimeState.ClearWeaponState(player: Player)
	WeaponStatesByPlayer[player] = cloneWeaponState(DEFAULT_WEAPON_STATE)
	WeaponChanged:Fire(player)
end

function ClientRuntimeState.SetWeaponAiming(player: Player, value: boolean)
	ClientRuntimeState.SetWeaponState(player, {
		Aiming = value,
	})
end

function ClientRuntimeState.IsWeaponAiming(player: Player): boolean
	return ClientRuntimeState.GetWeaponState(player).Aiming
end

function ClientRuntimeState.ObserveWeaponState(player: Player, callback: (WeaponState) -> ()): RBXScriptConnection
	callback(ClientRuntimeState.ReadWeaponState(player))

	return WeaponChanged.Event:Connect(function(changedPlayer: Player)
		if changedPlayer == player then
			callback(ClientRuntimeState.ReadWeaponState(player))
		end
	end)
end

function ClientRuntimeState.Clear(player: Player)
	StatesByPlayer[player] = nil
	WeaponStatesByPlayer[player] = nil
	WeaponChanged:Fire(player)
end

return ClientRuntimeState