--!strict
--[[
	@class FPSSystem

	@desc
	Boot orchestration for the server-side ACS combat engine.
	Initializes shared state, wires player lifecycle and kill credit,
	and binds all handler modules (Replication / Equipment / Combat).

	Expected to be required exactly once by Gameplay/FPSSystem.server.luau.
	Banning is handled by AdminRegistry.BanManager (Players:BanAsync)
	instead of an in-memory temp-ban table.
]]

--// Services

const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const DamageRuntimeState = require(ServerScriptService.Services.Combat.DamageRuntimeState)

const State = require(script.Core.State)
const Security = require(script.Core.Security)

const Replication = require(script.Handlers.Replication)
const Equipment = require(script.Handlers.Equipment)
const Combat = require(script.Handlers.Combat)

--// Constants

-- Kill credit rewards (matches legacy behaviour).
const KillCredit = 50
const KillExperienceReward = 45

--// Internal State

local Initialized = false

--// Kill Credit

local function SetupKillCredit(humanoid: Humanoid)
	humanoid.Died:Connect(function()
		local lastDamagerUserId = DamageRuntimeState.GetLastDamager(humanoid)
		if not lastDamagerUserId then
			return
		end

		local killer = Players:GetPlayerByUserId(lastDamagerUserId)
		if not killer then
			return
		end

		ProfileManager.AddCash(killer, KillCredit)
		ProfileManager.AddKills(killer, 1)
		ProfileManager.AddExperience(killer, KillExperienceReward)
	end)
end

--// Player Lifecycle

local function OnCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 8) :: Humanoid?
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	SetupKillCredit(humanoid)
end

-- Enforces the GameRules blacklist at join time (behaviour lost in the
-- orginal refactor: banned UserIds were previously kicked on PlayerAdded).
local function IsBlacklisted(player: Player): boolean
	local gameRules = State.GameRules
	if not gameRules or type(gameRules.Blacklist) ~= "table" then
		return false
	end

	local playerId = player.UserId
	for _, bannedId in gameRules.Blacklist do
		if bannedId == playerId then
			return true
		end
	end

	return false
end

local function OnPlayerAdded(player: Player)
	if IsBlacklisted(player) then
		warn(`[FPSSystem] {player.Name} is blacklisted; kicking.`)
		player:Kick("Blacklisted")
		return
	end

	local existingConnection = State.CharacterConnections[player]
	if existingConnection then
		existingConnection:Disconnect()
	end

	State.CharacterConnections[player] = player.CharacterAdded:Connect(OnCharacterAdded)

	if player.Character then
		OnCharacterAdded(player.Character)
	end
end

local function OnPlayerRemoving(player: Player)
	local connection = State.CharacterConnections[player]
	if connection then
		connection:Disconnect()
		State.CharacterConnections[player] = nil
	end

	local weaponRigEntity = State.WeaponRigEntities[player]
	if weaponRigEntity then
		ECS.deleteEntity(weaponRigEntity)
		State.WeaponRigEntities[player] = nil
	end
end

--// Public API

function Init()
	if Initialized then
		warn("[FPSSystem] Init() called more than once; ignoring duplicate boot.")
		return
	end
	Initialized = true

	State.AuthToken = HttpService:GenerateGUID(true)

	-- Load ACS GameRules.Config (used for team-kill rules, walk speeds, etc.)
	local Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
	local Rules = Engine:WaitForChild("GameRules")
	State.GameRules = require(Rules:WaitForChild("Config"))

	-- Apply global walk speed from game rules (matches legacy behaviour)
	game.StarterPlayer.CharacterWalkSpeed = State.GameRules.NormalWalkSpeed

	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)

	for _, player in Players:GetPlayers() do
		OnPlayerAdded(player)
	end

	-- Handler Wiring
	Security.Init()
	Replication.Bind()
	Equipment.Bind()
	Combat.Bind()

	warn("[FPSSystem] Boot complete.")
end

return {
	Init = Init,
}
