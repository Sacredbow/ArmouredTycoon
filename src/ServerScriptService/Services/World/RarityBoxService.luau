--!strict
--[[
	@class RarityBoxService

	@desc
	Periodically spawns rarity-based loot boxes at configured spawn points.
	Players can touch boxes to receive cash/emerald rewards based on rarity.
	Mythical and Divine boxes require following the group owner.
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const RarityModule = require(ServerScriptService.Modules.RarityModule)
const FollowService = require(ServerScriptService.Services.External.FollowService)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const Janitor = require(ReplicatedStorage.Packages.janitor)

--// Constants

const SPAWN_INTERVAL = 60
const BOX_LIFETIME = 30

const FOLLOW_TARGET_ID = 1372952359
const FOLLOW_TARGETS = table.freeze({ FOLLOW_TARGET_ID })

const REWARDS = table.freeze({
	Common = { cash = { 3000, 5000 } },
	Uncommon = { cash = { 10000, 15000 } },
	Rare = { cash = { 35000, 50000 } },
	Legendary = { cash = { 55000, 70000 } },
	Mythical = { cash = { 100000, 180000 }, emerald = { 40, 80 }, requiresFollow = true },
	Divine = { cash = { 300000, 350000 }, emerald = { 80, 120 }, requiresFollow = true },
})

--// Module

local RarityBoxService = {}
RarityBoxService.__index = RarityBoxService
local ActiveService: any? = nil

local function _rng(range)
	return math.random(range[1], range[2])
end

local function CheckFollowing(UserId: number): boolean
	for _, Id in FOLLOW_TARGETS do
		if FollowService.IsFollowing(UserId, Id, "") then
			return true
		end
	end
	return false
end

function RarityBoxService.new(packets)
	local self = setmetatable({}, RarityBoxService)
	self.Packets = packets
	self.BoxFolder = Instance.new("Folder")
	self.BoxFolder.Name = "RarityBoxes"
	self.BoxFolder.Parent = workspace
	self.SpawnPoints = workspace:WaitForChild("BoxSpawnPoints")
	ActiveService = self
	return self
end

function RarityBoxService:_GiveReward(player: Player, boxName: string)
	local spec = REWARDS[boxName]
	if not spec then
		return
	end

	if spec.requiresFollow and not CheckFollowing(player.UserId) then
		self.Packets.packets.GameEvent.sendTo({ ["type"] = "NotFollowing" }, player)
		return
	end

	if spec.cash then
		ProfileManager.AddCash(player, _rng(spec.cash))
	end
	if spec.emerald then
		ProfileManager.AddEmerald(player, _rng(spec.emerald))
	end
end

function RarityBoxService:_SpawnBox()
	local spawnPoints = self.SpawnPoints:GetChildren()
	if #spawnPoints == 0 then
		return
	end

	local pick = spawnPoints[math.random(1, #spawnPoints)]
	local RandomBox = RarityModule:SpawnRandomBox()
	if not RandomBox then
		warn("Error while trying to get a Random Box")
		return
	end

	local BoxClone = RandomBox:Clone()
	local PrimaryPart = BoxClone.PrimaryPart

	if not PrimaryPart then
		BoxClone:Destroy()
		return
	end

	if BoxClone.Name == "Divine" then
		self.Packets.packets.GameEvent.sendToAll({ ["type"] = "GunRarity", valueString = "Divine" })
	end

	BoxClone:PivotTo(pick.CFrame)
	BoxClone.Parent = self.BoxFolder

	ECS.createEntity({
		Name = `{BoxClone.Name}:RarityBoxLifetime`,
		Model = BoxClone,
		ScheduledTask = {
			delay = BOX_LIFETIME,
			elapsed = 0,
			kind = "RarityBoxExpire",
			box = BoxClone,
		},
	})

	local claimed = false
	const boxJanitor = Janitor.new()
	boxJanitor:LinkToInstance(BoxClone)
	local touchConnection: RBXScriptConnection?
	touchConnection = PrimaryPart.Touched:Connect(function(hit)
		if claimed then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local plr = character and Players:GetPlayerFromCharacter(character)
		if not plr then
			return
		end

		claimed = true
		local boxName = BoxClone.Name
		boxJanitor:Cleanup()
		if BoxClone.Parent then
			BoxClone:Destroy()
		end
		self:_GiveReward(plr, boxName)
	end)
	boxJanitor:Add(touchConnection, "Disconnect", "Touch")
end

function RarityBoxService.SpawnActive()
	if ActiveService then
		ActiveService:_SpawnBox()
	end
end

function RarityBoxService:Init()
	ECS.createEntity({
		Name = "RarityBoxSpawner",
		ScheduledTask = {
			delay = SPAWN_INTERVAL,
			repeatEvery = SPAWN_INTERVAL,
			elapsed = 0,
			kind = "RarityBoxSpawn",
		},
	})
end

return RarityBoxService
