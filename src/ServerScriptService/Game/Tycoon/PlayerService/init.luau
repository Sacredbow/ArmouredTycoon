--!strict
-- Player lifecycle adapter. Gameplay state lives in ECS components and is
-- processed by systems; this module only translates Roblox lifecycle events.
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const Observers = require(ReplicatedStorage.Packages.Observers)
const TeleportGraceDuration = 2
const PlayerSpawns = workspace:WaitForChild("PlayerSpawns")
local PlayerObserverStop: (() -> ())?
local CharacterObserverStop: (() -> ())?

local function FindPlayerEntity(Player: Player): number?
	for Entity, PlayerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if PlayerRef == Player then
			return Entity
		end
	end
	return nil
end

local function FindOwnedTycoon(Player: Player): number?
	for Entity, OwnerData in ECS.world:query(ECS.Components.Owner) do
		if OwnerData.player == Player then
			return Entity
		end
	end
	return nil
end

local function ApplySpawnProtection(Player: Player, Character: Model)
	const Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 8)
	if not Humanoid or not Humanoid:IsA("Humanoid") or Player.Character ~= Character then
		return
	end
	Humanoid.Health = math.huge
	const Entity = FindPlayerEntity(Player)
	if Entity then
		ECS.world:set(
			Entity,
			ECS.Components.SpawnProtection,
			{ Character = Character, Humanoid = Humanoid, Remaining = 10 }
		)
	end
end

local function AllowServerTeleport(Player: Player, Duration: number?)
	const Entity = FindPlayerEntity(Player)
	if Entity then
		ECS.world:set(Entity, ECS.Components.TeleportGrace, os.clock() + (Duration or TeleportGraceDuration))
	end
end

local function TeleportToSpawn(Player: Player, Character: Model)
	const Spawns = PlayerSpawns:GetChildren()
	if #Spawns == 0 then
		return
	end
	AllowServerTeleport(Player)
	Character:PivotTo(Spawns[math.random(1, #Spawns)].CFrame)
end

local function ApplySpawnHighlight(Player: Player, Character: Model)
	const Highlight = Instance.new("Highlight")
	Highlight.OutlineColor = Color3.new(1, 1, 1)
	Highlight.FillColor = Color3.new(1, 1, 1)
	Highlight.FillTransparency = 0.7
	Highlight.Parent = Character
	const Entity = FindPlayerEntity(Player)
	if Entity then
		ECS.world:set(Entity, ECS.Components.SpawnHighlight, { Highlight = Highlight, Remaining = 2 })
	end
end

local function OnPlayerAdded(Player: Player)
	if FindPlayerEntity(Player) then
		return
	end
	ECS.createEntity({
		Name = Player.Name .. ":Player",
		PlayerRef = Player,
		PlayerState = {},
		PlayerMultiplier = 1,
		ArmourEquipped = false,
		CanRebirth = false,
		TeleportGrace = 0,
		Surrendering = false,
		GamepassOwnership = {},
		X2 = false,
		Electrified = false,
		RocketActivated = false,
		FriendBoost = { count = 0, friendUserIds = {} },
	})
end

local function OnCharacterAdded(Player: Player, Character: Model)
	ApplySpawnProtection(Player, Character)
	if FindOwnedTycoon(Player) then
		return
	end
	TeleportToSpawn(Player, Character)
	ApplySpawnHighlight(Player, Character)
end

local function OnPlayerRemoving(Player: Player)
	const Entity = FindPlayerEntity(Player)
	if Entity then
		ECS.deleteEntity(Entity)
	end
end

const PlayerService = {}
function PlayerService.Init()
	if PlayerObserverStop then
		return
	end
	PlayerObserverStop = Observers.observePlayer(function(Player: Player)
		OnPlayerAdded(Player)
		return function()
			OnPlayerRemoving(Player)
		end
	end)
	CharacterObserverStop = Observers.observeCharacter(function(Player: Player, Character: Model)
		OnCharacterAdded(Player, Character)
	end)
end

return PlayerService
