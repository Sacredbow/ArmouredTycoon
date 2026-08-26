--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Network.Packets)

export type State = {
	Multiplier: number,
	Power: boolean,
	ArmourEquipped: boolean,
	CanRebirth: boolean,
	AntiCheatTeleportGraceUntil: number,
	Surrender: boolean,
	GamepassOwnership: { [number]: boolean },
}

local DefaultState: State = {
	Multiplier = 1,
	Power = false,
	ArmourEquipped = false,
	CanRebirth = false,
	AntiCheatTeleportGraceUntil = 0,
	Surrender = false,
	GamepassOwnership = {},
}

local StatesByPlayer: { [Player]: State } = {}

local PlayerRuntimeState = {}

local function cloneDefaults(): State
	return table.clone(DefaultState) :: State
end

function PlayerRuntimeState.Get(player: Player): State
	local state = StatesByPlayer[player]
	if not state then
		state = cloneDefaults()
		StatesByPlayer[player] = state
	end

	return state
end

function PlayerRuntimeState.Clear(player: Player)
	StatesByPlayer[player] = nil
end

function PlayerRuntimeState.ResetTycoonState(player: Player)
	local state = PlayerRuntimeState.Get(player)
	state.Multiplier = DefaultState.Multiplier
	state.Power = DefaultState.Power
	state.ArmourEquipped = DefaultState.ArmourEquipped
	PlayerRuntimeState.SetCanRebirth(player, DefaultState.CanRebirth)
end

function PlayerRuntimeState.GetMultiplier(player: Player): number
	return PlayerRuntimeState.Get(player).Multiplier
end

function PlayerRuntimeState.SetMultiplier(player: Player, value: number)
	PlayerRuntimeState.Get(player).Multiplier = value
end

function PlayerRuntimeState.HasPower(player: Player): boolean
	return PlayerRuntimeState.Get(player).Power
end

function PlayerRuntimeState.SetPower(player: Player, value: boolean)
	PlayerRuntimeState.Get(player).Power = value
end

function PlayerRuntimeState.HasArmourEquipped(player: Player): boolean
	return PlayerRuntimeState.Get(player).ArmourEquipped
end

function PlayerRuntimeState.SetArmourEquipped(player: Player, value: boolean)
	PlayerRuntimeState.Get(player).ArmourEquipped = value
end

function PlayerRuntimeState.CanRebirth(player: Player): boolean
	return PlayerRuntimeState.Get(player).CanRebirth
end

function PlayerRuntimeState.SetCanRebirth(player: Player, value: boolean)
	local state = PlayerRuntimeState.Get(player)
	if state.CanRebirth == value then
		return
	end

	state.CanRebirth = value
	Packets.packets.GameEvent.sendTo({ ["type"] = "CanRebirth", valueBoolean = value }, player)
end

function PlayerRuntimeState.GetAntiCheatTeleportGraceUntil(player: Player): number
	return PlayerRuntimeState.Get(player).AntiCheatTeleportGraceUntil
end

function PlayerRuntimeState.SetAntiCheatTeleportGraceUntil(player: Player, value: number)
	PlayerRuntimeState.Get(player).AntiCheatTeleportGraceUntil = value
end

function PlayerRuntimeState.IsSurrendering(player: Player): boolean
	return PlayerRuntimeState.Get(player).Surrender
end

function PlayerRuntimeState.SetSurrendering(player: Player, value: boolean)
	PlayerRuntimeState.Get(player).Surrender = value
end

function PlayerRuntimeState.HasGamepassOwned(player: Player, gamepassId: number): boolean
	return PlayerRuntimeState.Get(player).GamepassOwnership[gamepassId] == true
end

function PlayerRuntimeState.SetGamepassOwned(player: Player, gamepassId: number, value: boolean)
	PlayerRuntimeState.Get(player).GamepassOwnership[gamepassId] = value
end

Players.PlayerRemoving:Connect(function(player)
	PlayerRuntimeState.Clear(player)
end)

return PlayerRuntimeState
