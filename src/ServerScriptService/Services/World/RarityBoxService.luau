--!strict

-- Rarity boxes are ECS entities. This module only owns world asset setup and
-- reward side effects; box lifetime and intent processing run in systems.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local RarityModule = require(ServerScriptService.Modules.RarityModule)
local FollowService = require(ServerScriptService.Services.External.FollowService)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local Janitor = require(ReplicatedStorage.Packages.janitor)
local PromptIntentBridge = require(ServerScriptService.ECS.PromptIntentBridge)

local SPAWN_INTERVAL = 60
local BOX_LIFETIME = 30
local RandomGenerator = Random.new()
local FOLLOW_TARGETS = table.freeze({ 1372952359 })
local REWARDS = table.freeze({
	Common = { cash = { 3000, 5000 } },
	Uncommon = { cash = { 10000, 15000 } },
	Rare = { cash = { 35000, 50000 } },
	Legendary = { cash = { 55000, 70000 } },
	Mythical = { cash = { 100000, 180000 }, emerald = { 40, 80 }, requiresFollow = true },
	Divine = { cash = { 300000, 350000 }, emerald = { 80, 120 }, requiresFollow = true },
})

local RarityBoxService = {}
local Packets: any
local BoxFolder: Folder
local SpawnPoints: Instance
local Initialized = false

local function RandomInRange(Range: { number }): number
	return RandomGenerator:NextInteger(Range[1], Range[2])
end

local function IsFollowing(UserId: number): boolean
	for _, TargetId in FOLLOW_TARGETS do
		if FollowService.IsFollowing(UserId, TargetId, "") then
			return true
		end
	end
	return false
end

local function GiveReward(Player: Player, BoxName: string)
	local Spec = REWARDS[BoxName]
	if not Spec then
		return
	end
	if Spec.requiresFollow and not IsFollowing(Player.UserId) then
		Packets.packets.GameEvent.sendTo({ ["type"] = "NotFollowing" }, Player)
		return
	end
	if Spec.cash then
		ProfileManager.AddCash(Player, RandomInRange(Spec.cash))
	end
	if Spec.emerald then
		ProfileManager.AddEmerald(Player, RandomInRange(Spec.emerald))
	end
end

local function SpawnBox(): boolean
	local Points = SpawnPoints:GetChildren()
	if #Points == 0 then
		return false
	end
	local SpawnPoint = Points[RandomGenerator:NextInteger(1, #Points)]
	local RandomBox = RarityModule:SpawnRandomBox()
	if not RandomBox then
		warn("Error while trying to get a Random Box")
		return false
	end

	local Box = RandomBox:Clone()
	local PrimaryPart = Box.PrimaryPart
	if not PrimaryPart then
		Box:Destroy()
		return false
	end
	if Box.Name == "Divine" then
		Packets.packets.GameEvent.sendToAll({ ["type"] = "GunRarity", valueString = "Divine" })
	end

	Box:PivotTo(SpawnPoint.CFrame)
	Box.Parent = BoxFolder
	local Entity = ECS.createEntity({
		Name = "RarityBoxLifetime:" .. Box.Name,
		Model = Box,
		RarityBoxLifetime = { Remaining = BOX_LIFETIME, Box = Box },
		RarityBoxState = { Box = Box, Claimed = false },
	})

	local BoxJanitor = Janitor.new()
	BoxJanitor:LinkToInstance(Box)
	local Connections: { any } = {}
	PromptIntentBridge.BindContact(PrimaryPart, "RarityBoxClaim", {
		BoxEntity = Entity,
		Box = Box,
		BoxName = Box.Name,
	}, Connections)
	for _, Connection in Connections do
		BoxJanitor:Add(Connection, "Disconnect", "Contact")
	end
	return true
end

local function Collect(Entity: number, Player: Player)
	local State = ECS.world:get(Entity, ECS.Components.RarityBoxState)
	if not State or State.Claimed then
		return
	end
	State.Claimed = true
	ECS.world:set(Entity, ECS.Components.RarityBoxState, State)
	local BoxName = State.Box and State.Box.Name
	if State.Box and State.Box.Parent then
		State.Box:Destroy()
	end
	if typeof(BoxName) == "string" then
		GiveReward(Player, BoxName)
	end
	ECS.deleteEntity(Entity)
end

function RarityBoxService.CollectActive(Entity: number, Player: Player)
	Collect(Entity, Player)
end

function RarityBoxService.SpawnActive(): boolean
	return Initialized and SpawnBox() or false
end

function RarityBoxService.Init(PacketValue: any)
	if Initialized then
		return
	end
	Packets = PacketValue
	BoxFolder = Instance.new("Folder")
	BoxFolder.Name = "RarityBoxes"
	BoxFolder.Parent = workspace
	SpawnPoints = workspace:WaitForChild("BoxSpawnPoints")
	ECS.createEntity({
		Name = "RarityBoxSpawner",
		RarityBoxSpawner = { Remaining = SPAWN_INTERVAL },
	})
	Initialized = true
end

return RarityBoxService
