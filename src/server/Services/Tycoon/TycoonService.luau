local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local DataTemplate = require(ServerScriptService.DataManager.DataTemplate)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local TycoonClass = require(ServerScriptService.Classes.Tycoon)
local RagdollModule = require(ServerScriptService.Modules.RagdollModule)
local CollisionModule = require(ServerScriptService.Modules.CollisionManager)

local TycoonService = {}
TycoonService.__index = TycoonService

type ConstructionData = {
	PurchasedButtons: { string },
}

local function clearSavedConstruction(player: Player)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	local constructionData = profile.Data.TycoonConstruction
	if type(constructionData) ~= "table" then
		profile.Data.TycoonConstruction = {
			PurchasedButtons = {},
		}
		return
	end

	(constructionData :: ConstructionData).PurchasedButtons = {}
end

function TycoonService.new(playerService, purchaseService)
	local self = setmetatable({}, TycoonService)
	self.PlayerService = playerService
	self.PurchaseService = purchaseService
	self.Tycoons = {}
	self.TycoonsByOwner = {}
	return self
end

function TycoonService:Init()
	local tycoonsFolder = workspace:WaitForChild("Tycoons")
	print("Initializing tycoons...")

	for _, tycoonModel in ipairs(tycoonsFolder:GetChildren()) do
		if tycoonModel:IsA("Model") then
			local tycoon = TycoonClass.new(tycoonModel, self.PlayerService, self.PurchaseService, RagdollModule, CollisionModule)
			tycoon:Init()
			table.insert(self.Tycoons, tycoon)
			print("Setup complete:", tycoonModel.Name)
		end
	end

	print("All tycoons initialized!")
end


function TycoonService:RegisterOwner(player, tycoon)
	self.TycoonsByOwner[player] = tycoon
end

function TycoonService:GetTycoonForPlayer(player)
	return self.TycoonsByOwner[player]
end

function TycoonService:GetAllTycoons()
	return self.Tycoons
end

function TycoonService:FindUnclaimedTycoon()
	for _, tycoon in ipairs(self.Tycoons) do
		if not tycoon.OwnerValue.Value then 
			return tycoon
		end
	end
	return nil
end

function TycoonService:_OnPlayerRemoving(player)
	local tycoon = self.TycoonsByOwner[player]
	if tycoon then
		tycoon:Cleanup() 
		self.TycoonsByOwner[player] = nil
	end
end


function TycoonService:Rebirth(player: Player, rebirthAmount: number?)
	local tycoon = self.TycoonsByOwner[player]
	local amountToAward = rebirthAmount or 1

	ProfileManager.AddRebirths(player, amountToAward)
	ProfileManager.SetCash(player, DataTemplate.Cash)

	if not tycoon then
		clearSavedConstruction(player)
		warn(`[TycoonService] Rebirth applied for {player.Name} without an active tycoon`)
		return
	end

	tycoon:_ClearSavedConstruction(player)
	tycoon:Cleanup()
	self.TycoonsByOwner[player] = nil
end



return TycoonService
