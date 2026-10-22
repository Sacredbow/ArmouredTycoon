--!strict
--[[
	PlayerService owns Roblox player lifecycle only. Player flags and tycoon
	ownership are stored in ECS components; Observers owns connection cleanup.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const ECS = require(ReplicatedStorage.ECS)
const Observers = require(ReplicatedStorage.Packages.Observers)
const FriendService = require(script.FriendService)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

const PlayerService = {}

const TeleportGraceDuration = 2
const PlayerStateKeys = {
	X2 = "X2",
	Electrified = "Electrified",
	RocketActivated = "RocketActivated",
}

local function GetPlayerEntity(self, Player: Player): number?
	return self.PlayerEntities[Player]
end

local function GetPlayerState(self, Player: Player): any?
	const Entity = GetPlayerEntity(self, Player)
	return Entity and ECS.get(Entity, "PlayerState")
end

local function SetPlayerFlag(self, Player: Player, Flag: string, Value: boolean)
	const State = GetPlayerState(self, Player)
	if not State then
		return
	end

	State.flags[Flag] = Value
	ECS.set(self.PlayerEntities[Player], "PlayerState", State)
end

local function HasPlayerFlag(self, Player: Player, Flag: string): boolean
	const State = GetPlayerState(self, Player)
	return State ~= nil and State.flags[Flag] == true
end

function PlayerService.create()
	const Self = {}
	Self.PlayerEntities = {} :: { [Player]: number }
	Self.PlayerSpawns = workspace:WaitForChild("PlayerSpawns")
	FriendService.Init()
	Self.PlayerObserverStop = nil
	Self.CharacterObserverStop = nil
	return Self
end

function PlayerService:_ApplySpawnProtection(Player: Player, Character: Model)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		Humanoid = Character:WaitForChild("Humanoid", 8)
	end
	if not Humanoid or not Humanoid:IsA("Humanoid") or Player.Character ~= Character then
		return
	end

	Humanoid.Health = math.huge
	ECS.createEntity({
		Name = Player.Name .. ":SpawnProtection",
		Model = Character,
		ScheduledTask = {
			delay = 10,
			elapsed = 0,
			kind = "SpawnProtection",
			player = Player,
			character = Character,
			humanoid = Humanoid,
		},
	})
end

function PlayerService:_OnPlayerAdded(Player: Player)
	if self.PlayerEntities[Player] then
		return
	end

	self.PlayerEntities[Player] = ECS.createEntity({
		Name = Player.Name .. ":Player",
		PlayerRef = Player,
		PlayerState = { flags = {} },
		FriendBoost = { count = 0, friendUserIds = {} },
	})
	PlayerRuntimeState.Get(Player)
end

function PlayerService:_OnCharacterAdded(Player: Player, Character: Model)
	self:_ApplySpawnProtection(Player, Character)
	if self:OwnsTycoon(Player) then
		return
	end
	self:_TeleportToSpawn(Player, Character)
	self:_ApplySpawnHighlight(Character)
end

function PlayerService:AllowServerTeleport(Player: Player, Duration: number?)
	PlayerRuntimeState.SetTeleportGraceExpiry(Player, os.clock() + (Duration or TeleportGraceDuration))
end

function PlayerService:_TeleportToSpawn(Player: Player, Character: Model)
	const Spawns = self.PlayerSpawns:GetChildren()
	if #Spawns == 0 then
		return
	end

	self:AllowServerTeleport(Player)
	Character:PivotTo(Spawns[math.random(1, #Spawns)].CFrame)
end

function PlayerService:_ApplySpawnHighlight(Character: Model)
	const Highlight = Instance.new("Highlight")
	Highlight.OutlineColor = Color3.new(1, 1, 1)
	Highlight.FillColor = Color3.new(1, 1, 1)
	Highlight.FillTransparency = 0.7
	Highlight.Parent = Character
	ECS.createEntity({
		Name = Character.Name .. ":SpawnHighlightFade",
		ScheduledTask = {
			delay = 2,
			elapsed = 0,
			kind = "SpawnHighlightFade",
			highlight = Highlight,
		},
	})
end

function PlayerService:_OnPlayerRemoving(Player: Player)
	self:CleanupPlayer(Player)
end

function PlayerService:CleanupPlayer(Player: Player)
	const Entity = self.PlayerEntities[Player]
	if Entity then
		ECS.deleteEntity(Entity)
		self.PlayerEntities[Player] = nil
	end

	PlayerRuntimeState.SetCanRebirth(Player, false)
	PlayerRuntimeState.Clear(Player)
end

function PlayerService:RegisterPlayerTycoon(Player: Player, Tycoon: number)
	PlayerRuntimeState.SetCanRebirth(Player, false)
	if self.TycoonService then
		self.TycoonService:RegisterOwner(Player, Tycoon)
	end
end

function PlayerService:ReleaseTycoon(TycoonEntity: number)
	const State = ECS.get(TycoonEntity, "TycoonState")
	const Owner = State and State.owner
	if Owner then
		PlayerRuntimeState.SetCanRebirth(Owner, false)
	end
end

function PlayerService:Init()
	if self.PlayerObserverStop then
		return
	end

	self.PlayerObserverStop = Observers.observePlayer(function(Player: Player)
		self:_OnPlayerAdded(Player)
		return function()
			self:_OnPlayerRemoving(Player)
		end
	end)

	self.CharacterObserverStop = Observers.observeCharacter(function(Player: Player, Character: Model)
		self:_OnCharacterAdded(Player, Character)
	end)
end

function PlayerService:HasX2(Player: Player): boolean
	return HasPlayerFlag(self, Player, PlayerStateKeys.X2)
end

function PlayerService:SetX2(Player: Player, Value: boolean)
	SetPlayerFlag(self, Player, PlayerStateKeys.X2, Value)
end

function PlayerService:IsElectrified(Player: Player): boolean
	return HasPlayerFlag(self, Player, PlayerStateKeys.Electrified)
end

function PlayerService:SetElectrified(Player: Player, Value: boolean)
	SetPlayerFlag(self, Player, PlayerStateKeys.Electrified, Value)
end

function PlayerService:HasFriendBoost(Player: Player): boolean
	const Entity = GetPlayerEntity(self, Player)
	const State = Entity and ECS.get(Entity, "FriendBoost")
	return State ~= nil and State.count > 0
end

function PlayerService:SetFriendBoost(Player: Player, Value: boolean)
	const Entity = GetPlayerEntity(self, Player)
	if not Entity then
		return
	end

	const State = ECS.get(Entity, "FriendBoost") or { count = 0, friendUserIds = {} }
	if not Value then
		State.count = 0
		table.clear(State.friendUserIds)
	elseif State.count <= 0 then
		State.count = 1
	end
	ECS.set(Entity, "FriendBoost", State)
end

function PlayerService:GetFriendBoostMultiplier(Player: Player): number
	return FriendService.GetBoostMultiplier(Player)
end

function PlayerService:HasActivated(Player: Player): boolean
	return HasPlayerFlag(self, Player, PlayerStateKeys.RocketActivated)
end

function PlayerService:ActivateRocket(Player: Player, Value: boolean)
	SetPlayerFlag(self, Player, PlayerStateKeys.RocketActivated, Value)
end

function PlayerService:GetTycoon(Player: Player): number?
	if self.TycoonService then
		return self.TycoonService:GetTycoonForPlayer(Player)
	end
	return nil
end

function PlayerService:OwnsTycoon(Player: Player): boolean
	return self:GetTycoon(Player) ~= nil
end

return PlayerService