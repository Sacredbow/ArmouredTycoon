--!strict
--[[
	PlayerService is a lifecycle boundary. Per-player flags and ownership are
	plain ECS components; this service only handles Roblox connections and
	commands that mutate those components.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local FriendService = require(script.FriendService)
local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

local PlayerService = {}

local TELEPORT_GRACE_DURATION = 2
local STATES = {
	X2 = "X2",
	Electrified = "Electrified",
	FriendBoost = "FriendBoost",
	RocketActivated = "RocketActivated",
}

local function getEntity(self, player: Player): number?
	return self.PlayerEntities[player]
end

local function getState(self, player: Player): any?
	local entity = getEntity(self, player)
	return entity and ECS.get(entity, "PlayerState")
end

local function setFlag(self, player: Player, flag: string, value: boolean)
	local state = getState(self, player)
	if not state then return end
	state.flags[flag] = value
	ECS.set(self.PlayerEntities[player], "PlayerState", state)
end

local function hasFlag(self, player: Player, flag: string): boolean
	local state = getState(self, player)
	return state ~= nil and state.flags[flag] == true
end

function PlayerService.create()
	local self = {}
	self.PlayerEntities = {} :: {[Player]: number}
	self.PlayerTycoons = {} :: {[Player]: number}
	self.CharacterConnections = {} :: {[Player]: RBXScriptConnection}
	self.PlayerSpawns = workspace:WaitForChild("PlayerSpawns")
	self.FriendService = FriendService.create(self)
	self.FriendService:Init()
	return self
end

function PlayerService:_OnPlayerAdded(player: Player)
	if self.PlayerEntities[player] then return end
	self.PlayerEntities[player] = ECS.createEntity({
		Name = player.Name .. ":Player",
		PlayerRef = player,
		PlayerState = {flags = {}},
	})
	PlayerRuntimeState.Get(player)
	self.CharacterConnections[player] = player.CharacterAdded:Connect(function(character)
		self:_OnCharacterAdded(player, character)
	end)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = math.huge
		ECS.createEntity({
			Name = player.Name .. ":SpawnProtection",
			Model = character,
			ScheduledTask = {
				delay = 10,
				elapsed = 0,
				kind = "SpawnProtection",
				player = player,
				character = character,
				humanoid = humanoid,
			},
		})
	end
end

function PlayerService:_OnCharacterAdded(player: Player, character: Model)
	if self:OwnsTycoon(player) then return end
	self:_TeleportToSpawn(player, character)
	self:_ApplySpawnHighlight(character)
end

function PlayerService:AllowServerTeleport(player: Player, duration: number?)
	PlayerRuntimeState.SetAntiCheatTeleportGraceUntil(player, os.clock() + (duration or TELEPORT_GRACE_DURATION))
end

function PlayerService:_TeleportToSpawn(player: Player, character: Model)
	local spawns = self.PlayerSpawns:GetChildren()
	if #spawns == 0 then return end
	self:AllowServerTeleport(player)
	character:PivotTo(spawns[math.random(1, #spawns)].CFrame)
end

function PlayerService:_ApplySpawnHighlight(character: Model)
	local highlight = Instance.new("Highlight")
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.7
	highlight.Parent = character
	ECS.createEntity({
		Name = character.Name .. ":SpawnHighlightFade",
		ScheduledTask = {
			delay = 2,
			elapsed = 0,
			kind = "SpawnHighlightFade",
			highlight = highlight,
		},
	})
end

function PlayerService:_OnPlayerRemoving(player: Player)
	self:CleanupPlayer(player)
end

function PlayerService:CleanupPlayer(player: Player)
	local entity = self.PlayerEntities[player]
	if entity then
		ECS.deleteEntity(entity)
		self.PlayerEntities[player] = nil
	end
	self.PlayerTycoons[player] = nil
	local connection = self.CharacterConnections[player]
	if connection then
		connection:Disconnect()
		self.CharacterConnections[player] = nil
	end
	PlayerRuntimeState.SetCanRebirth(player, false)
	PlayerRuntimeState.Clear(player)
end

function PlayerService:RegisterPlayerTycoon(player: Player, tycoon: number)
	self.PlayerTycoons[player] = tycoon
	PlayerRuntimeState.SetCanRebirth(player, false)
	if self.TycoonService then self.TycoonService:RegisterOwner(player, tycoon) end
end

function PlayerService:ReleaseTycoon(entity: number)
	for player, ownedEntity in self.PlayerTycoons do
		if ownedEntity == entity then
			self.PlayerTycoons[player] = nil
			PlayerRuntimeState.SetCanRebirth(player, false)
		end
	end
end

function PlayerService:Init()
	Players.PlayerAdded:Connect(function(player) self:_OnPlayerAdded(player) end)
	Players.PlayerRemoving:Connect(function(player) self:_OnPlayerRemoving(player) end)
	for _, player in Players:GetPlayers() do
		task.defer(function() self:_OnPlayerAdded(player) end)
	end
end

function PlayerService:HasX2(player: Player): boolean return hasFlag(self, player, STATES.X2) end
function PlayerService:SetX2(player: Player, value: boolean) setFlag(self, player, STATES.X2, value) end
function PlayerService:IsElectrified(player: Player): boolean return hasFlag(self, player, STATES.Electrified) end
function PlayerService:SetElectrified(player: Player, value: boolean) setFlag(self, player, STATES.Electrified, value) end
function PlayerService:HasFriendBoost(player: Player): boolean return hasFlag(self, player, STATES.FriendBoost) end
function PlayerService:SetFriendBoost(player: Player, value: boolean) setFlag(self, player, STATES.FriendBoost, value) end

function PlayerService:GetFriendBoostMultiplier(player: Player): number
	return if self.FriendService then self.FriendService:GetBoostMultiplier(player) else 1
end

function PlayerService:HasActivated(player: Player): boolean return hasFlag(self, player, STATES.RocketActivated) end
function PlayerService:ActivateRocket(player: Player, value: boolean) setFlag(self, player, STATES.RocketActivated, value) end

function PlayerService:GetTycoon(player: Player): number?
	if self.TycoonService then return self.TycoonService:GetTycoonForPlayer(player) end
	return self.PlayerTycoons[player]
end

function PlayerService:OwnsTycoon(player: Player): boolean
	return self:GetTycoon(player) ~= nil
end

return PlayerService