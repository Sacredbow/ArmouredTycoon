--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Network.Packets)

export type State = {
	Multiplier: number,
	ArmourEquipped: boolean,
	CanRebirth: boolean,
	AntiCheatTeleportGraceUntil: number,
	Surrender: boolean,
	GamepassOwnership: { [number]: boolean },
}

local DefaultState: State = {
	Multiplier = 1,
	ArmourEquipped = false,
	CanRebirth = false,
	AntiCheatTeleportGraceUntil = 0,
	Surrender = false,
	GamepassOwnership = {},
}

local StatesByPlayer: { [Player]: State } = {}

local PlayerRuntimeState = {}
local CharacterConnections: { [Player]: RBXScriptConnection } = {}

local function bindCharacter(player: Player)
	CharacterConnections[player] = player.CharacterAdded:Connect(function()
		local state = StatesByPlayer[player]
		if state then
			state.ArmourEquipped = false
			state.Surrender = false
			state.AntiCheatTeleportGraceUntil = 0
		end
	end)
end

local function cloneDefaults(): State
	local state = table.clone(DefaultState)
	state.GamepassOwnership = {}
	return state
end

function PlayerRuntimeState.Get(player: Player): State
	local state = StatesByPlayer[player]
	if not state then
		state = cloneDefaults()
		if player.Parent == Players then
			StatesByPlayer[player] = state
		end
	end

	return state
end

function PlayerRuntimeState.Clear(player: Player)
	StatesByPlayer[player] = nil
end

function PlayerRuntimeState.ResetTycoonState(player: Player)
	local state = PlayerRuntimeState.Get(player)
	state.Multiplier = DefaultState.Multiplier
	state.ArmourEquipped = DefaultState.ArmourEquipped
	PlayerRuntimeState.SetCanRebirth(player, DefaultState.CanRebirth)
end

function PlayerRuntimeState.GetMultiplier(player: Player): number
	return PlayerRuntimeState.Get(player).Multiplier
end

function PlayerRuntimeState.SetMultiplier(player: Player, value: number)
	PlayerRuntimeState.Get(player).Multiplier = value
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

function PlayerRuntimeState.GetGamepassOwnership(player: Player, gamepassId: number): boolean?
	return PlayerRuntimeState.Get(player).GamepassOwnership[gamepassId]
end

function PlayerRuntimeState.HasGamepassOwned(player: Player, gamepassId: number): boolean
	return PlayerRuntimeState.Get(player).GamepassOwnership[gamepassId] == true
end

function PlayerRuntimeState.SetGamepassOwned(player: Player, gamepassId: number, value: boolean)
	PlayerRuntimeState.Get(player).GamepassOwnership[gamepassId] = value
end

for _, player in Players:GetPlayers() do
	bindCharacter(player)
end

Players.PlayerAdded:Connect(bindCharacter)
Players.PlayerRemoving:Connect(function(player)
	local connection = CharacterConnections[player]
	if connection then
		connection:Disconnect()
		CharacterConnections[player] = nil
	end
	PlayerRuntimeState.Clear(player)
end)

return PlayerRuntimeState
