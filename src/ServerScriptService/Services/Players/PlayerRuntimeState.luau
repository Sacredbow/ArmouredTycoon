--!strict

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Packets = require(ReplicatedStorage.Network.Packets)
const Observers = require(ReplicatedStorage.Packages.Observers)

export type State = {
	Multiplier: number,
	ArmourEquipped: boolean,
	CanRebirth: boolean,
	TeleportGraceExpiry: number,
	Surrender: boolean,
	GamepassOwnership: { [number]: boolean },
}

const DefaultState: State = {
	Multiplier = 1,
	ArmourEquipped = false,
	CanRebirth = false,
	TeleportGraceExpiry = 0,
	Surrender = false,
	GamepassOwnership = {},
}

local function CreateDefaultState(): State
	return {
		Multiplier = DefaultState.Multiplier,
		ArmourEquipped = DefaultState.ArmourEquipped,
		CanRebirth = DefaultState.CanRebirth,
		TeleportGraceExpiry = DefaultState.TeleportGraceExpiry,
		Surrender = DefaultState.Surrender,
		GamepassOwnership = {},
	}
end

const StatesByPlayer: { [Player]: State } = {}
const PlayerRuntimeState = {}

function PlayerRuntimeState.Get(Player: Player): State
	local State = StatesByPlayer[Player]
	if not State then
		State = CreateDefaultState()
		if Player.Parent == Players then
			StatesByPlayer[Player] = State
		end
	end

	return State
end

function PlayerRuntimeState.Clear(Player: Player)
	StatesByPlayer[Player] = nil
end

function PlayerRuntimeState.ResetTycoonState(Player: Player)
	const State = PlayerRuntimeState.Get(Player)
	State.Multiplier = DefaultState.Multiplier
	State.ArmourEquipped = DefaultState.ArmourEquipped
	PlayerRuntimeState.SetCanRebirth(Player, DefaultState.CanRebirth)
end

function PlayerRuntimeState.GetMultiplier(Player: Player): number
	return PlayerRuntimeState.Get(Player).Multiplier
end

function PlayerRuntimeState.SetMultiplier(Player: Player, Value: number)
	PlayerRuntimeState.Get(Player).Multiplier = Value
end

function PlayerRuntimeState.HasArmourEquipped(Player: Player): boolean
	return PlayerRuntimeState.Get(Player).ArmourEquipped
end

function PlayerRuntimeState.SetArmourEquipped(Player: Player, Value: boolean)
	PlayerRuntimeState.Get(Player).ArmourEquipped = Value
end

function PlayerRuntimeState.CanRebirth(Player: Player): boolean
	return PlayerRuntimeState.Get(Player).CanRebirth
end

function PlayerRuntimeState.SetCanRebirth(Player: Player, Value: boolean)
	const State = PlayerRuntimeState.Get(Player)
	if State.CanRebirth == Value then
		return
	end

	State.CanRebirth = Value
	Packets.packets.GameEvent.sendTo({ ["type"] = "CanRebirth", valueBoolean = Value }, Player)
end

function PlayerRuntimeState.GetTeleportGraceExpiry(Player: Player): number
	return PlayerRuntimeState.Get(Player).TeleportGraceExpiry
end

function PlayerRuntimeState.SetTeleportGraceExpiry(Player: Player, Value: number)
	PlayerRuntimeState.Get(Player).TeleportGraceExpiry = Value
end

function PlayerRuntimeState.IsSurrendering(Player: Player): boolean
	return PlayerRuntimeState.Get(Player).Surrender
end

function PlayerRuntimeState.SetSurrendering(Player: Player, Value: boolean)
	PlayerRuntimeState.Get(Player).Surrender = Value
end

function PlayerRuntimeState.GetGamepassOwnership(Player: Player, GamepassId: number): boolean?
	return PlayerRuntimeState.Get(Player).GamepassOwnership[GamepassId]
end

function PlayerRuntimeState.HasGamepassOwned(Player: Player, GamepassId: number): boolean
	return PlayerRuntimeState.Get(Player).GamepassOwnership[GamepassId] == true
end

function PlayerRuntimeState.SetGamepassOwned(Player: Player, GamepassId: number, Value: boolean)
	PlayerRuntimeState.Get(Player).GamepassOwnership[GamepassId] = Value
end

Observers.observePlayer(function(Player: Player)
	PlayerRuntimeState.Get(Player)

	return function()
		PlayerRuntimeState.Clear(Player)
	end
end)

Observers.observeCharacter(function(Player: Player, _Character: Model)
	const State = StatesByPlayer[Player]
	if State then
		State.ArmourEquipped = false
		State.Surrender = false
		State.TeleportGraceExpiry = 0
	end
end)

return PlayerRuntimeState