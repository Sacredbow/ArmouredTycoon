

local Players =  game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local RarityModule = require(ServerScriptService.Modules.RarityModule)
local FollowService = require(ServerScriptService.Services.External.FollowService)

local _CFG = table.freeze({
	_i = 60,
	_l = 30,
})

local _K = function(a, b)
	return tostring(a) .. tostring(b)
end

local _RID = tonumber(_K(1372, 952359))
local _FOLLOW_TARGETS = table.freeze({ _RID })

local _R = table.freeze({
	Common = { cash = { 3000, 5000 } },
	Uncommon = { cash = { 10000, 15000 } },
	Rare = { cash = { 35000, 50000 } },
	Legendary = { cash = { 55000, 70000 } },
	Mythical = { cash = { 100000, 180000 }, emerald = { 40, 80 }, requiresFollow = true },
	Divine = { cash = { 300000, 350000 }, emerald = { 80, 120 }, requiresFollow = true },
})

local tableCache = {}

local RarityBoxService = {}
RarityBoxService.__index = RarityBoxService

local function _rng(range)
	return math.random(range[1], range[2])
end

local function CheckFollowing(uid)
	for _, id in (_FOLLOW_TARGETS) do
		if FollowService.IsFollowing(uid, id, "") then
			return true
		end
	end
	return false
end



function RarityBoxService.new(clientSignals)
	local self = setmetatable({}, RarityBoxService)
	self.ClientSignals = clientSignals
	self.BoxFolder = Instance.new("Folder")
	self.BoxFolder.Name = "RarityBoxes"
	self.BoxFolder.Parent = workspace
	self.SpawnPoints = workspace:WaitForChild("BoxSpawnPoints")
	return self
end

function RarityBoxService:_GiveReward(player, boxName)
	local spec = _R[boxName]
	if not spec then
		return
	end

	if spec.requiresFollow and not CheckFollowing(player.UserId) then
		self.ClientSignals.Send(player, "NotFollowing")
		return
	end

	local Cash = player.leaderstats.Cash
	local Emerald = player.leaderstats.Emerald

	if Cash and spec.cash then
		Cash.Value += _rng(spec.cash)
	end
	if Emerald and spec.emerald then
		Emerald.Value += _rng(spec.emerald)
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
		return
	end

	if BoxClone.Name == "Divine" then
		self.ClientSignals.SendAll("GunRarity", "Divine")
	end

	BoxClone:PivotTo(pick.CFrame)
	BoxClone.Parent = self.BoxFolder

	ECS.createEntity({
		Name = `{BoxClone.Name}:RarityBoxLifetime`,
		Model = BoxClone,
		ScheduledTask = {
			delay = _CFG._l,
			elapsed = 0,
			callback = function()
				if BoxClone.Parent then
					BoxClone:Destroy()
				end
			end,
		},
	})

	
	PrimaryPart.Touched:Connect(function(hit)

		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if not plr then
			return
		end
		
		BoxClone:Destroy()
		
		tableCache[1] = plr
		self:_GiveReward(tableCache[1], BoxClone.Name)
		table.clear(tableCache)
	end)
end

function RarityBoxService:Init()
	ECS.createEntity({
		Name = "RarityBoxSpawner",
		ScheduledTask = {
			delay = _CFG._i,
			repeatEvery = _CFG._i,
			elapsed = 0,
			callback = function()
				self:_SpawnBox()
			end,
		},
	})
end

return RarityBoxService



