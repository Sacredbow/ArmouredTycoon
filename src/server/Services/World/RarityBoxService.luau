local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")


local RarityModule = require(ServerScriptService.Modules.RarityModule)
local FollowService = require(ServerScriptService.Services.External.FollowService)

local SPAWN_INTERVAL = 60
local BOX_LIFETIME = 30
local REWARDS = {
	Common =    { cash = {3000, 5000} },
	Uncommon =  { cash = {10000, 15000} },
	Rare =      { cash = {35000, 50000} },
	Legendary = { cash = {55000, 70000} },
	Mythical =  { cash = {100000, 180000}, emerald = {40, 80},   requiresFollow = true },
	Divine =    { cash = {300000, 350000}, emerald = {80, 120},  requiresFollow = true },
}

local BoxRegistry = {} -- preventing multiple players


local FOLLOW_IDS = {1372952359, 5330259633}

local RarityBoxService = {}
RarityBoxService.__index = RarityBoxService

function RarityBoxService.new(returnRequest, gunRarity)
	local self = setmetatable({}, RarityBoxService)
	self.ReturnRequest = returnRequest
	self.GunRarity = gunRarity
	self.BoxFolder = Instance.new("Folder")
	self.BoxFolder.Name = "RarityBoxes"
	self.BoxFolder.Parent = workspace
	self.SpawnPoints = workspace:WaitForChild("BoxSpawnPoints")
	return self
end

function RarityBoxService:_GiveReward(player, boxName)
	local reward = REWARDS[boxName]
	if not reward then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	if reward.requiresFollow then
		local isFollowing = false
		for _, id in ipairs(FOLLOW_IDS) do
			if FollowService.IsFollowing(player.UserId, id, "") then
				isFollowing = true
				break
			end
		end
		if not isFollowing then
			self.ReturnRequest:FireClient(player, "NotFollowing")
			return
		end
	end

	local cash = leaderstats:FindFirstChild("Cash")
	local emerald = leaderstats:FindFirstChild("Emerald")

	if cash and reward.cash then
		cash.Value += math.random(reward.cash[1], reward.cash[2])
	end
	if emerald and reward.emerald then
		emerald.Value += math.random(reward.emerald[1], reward.emerald[2])
	end
end

function RarityBoxService:_SpawnBox()
	local spawnPoints = self.SpawnPoints:GetChildren()
	if #spawnPoints == 0 then return end

	local randomSpawn = spawnPoints[math.random(1, #spawnPoints)]
	local boxModel = RarityModule:SpawnRandomBox()
	if not boxModel then return end

	local clone = boxModel:Clone()
	if not clone.PrimaryPart then return end

	if clone.Name == "Divine" then
		self.GunRarity:FireAllClients("Divine")
	end

	clone:PivotTo(randomSpawn.CFrame)
	clone.Parent = self.BoxFolder


	task.delay(BOX_LIFETIME, function()
		if clone.Parent then clone:Destroy() end
	end)

	local touched = false
	clone.PrimaryPart.Touched:Connect(function(hit)
		if touched then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		table.insert(BoxRegistry, player)

		if not player then
			 return
		end
		touched = true
		self:_GiveReward(BoxRegistry[1], clone.Name)
		clone:Destroy()
		table.clear(BoxRegistry)
	end)
end

function RarityBoxService:Init()
	task.spawn(function()
		while task.wait(SPAWN_INTERVAL) do
			self:_SpawnBox()
		end
	end)
end

return RarityBoxService