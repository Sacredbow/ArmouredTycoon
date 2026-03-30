local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GamePackage = ReplicatedStorage:WaitForChild("GamePackage")

local PlayerService =   require(ServerScriptService.Services.Tycoon.PlayerService)
local TycoonService = require(ServerScriptService.Services.Tycoon.TycoonService)
local PurchaseService = require(ServerScriptService.Services.Commerce.CommerceService)
local EnvironmentService = require(ServerScriptService.Services.World.EnvironmentService)
local RarityBoxService = require(ServerScriptService.Services.World.RarityBoxService)
local CodeService = require(ServerScriptService.Services.Commerce.CodeService)

local ReturnRequest = ReplicatedStorage.Remotes.ReturnRequest
local GunRarity = ReplicatedStorage.Remotes.Interface:WaitForChild("GunRarity")






local function LoadModule(name, loader)
	local start = os.clock()
	local result = loader()
	local elapsed = math.round((os.clock() - start) * 1000) / 1000
	warn(string.format("[Modules] Loaded %s, took %.3f seconds", name, elapsed))
	return result
end

local playerService = LoadModule("PlayerService", function()
	local s = PlayerService.new()
	s:Init()
	return s
end)

local purchaseService = LoadModule("PurchaseService", function()
	local s = PurchaseService.new(playerService)
	s:Init()
	return s
end)

local tycoonService = LoadModule("TycoonService", function()
	local s = TycoonService.new(playerService, purchaseService)
	s:Init()
	return s
end)

playerService.TycoonService = tycoonService

local environmentService = LoadModule("EnvironmentService", function()
	local s = EnvironmentService.new({
		LightingPackage = GamePackage.Lighting,
		Props = workspace.Map.Props,
		ReturnRequest = ReturnRequest
	})
	s:Init()
	return s
end)

local rarityBoxService = LoadModule("RarityBoxService", function()
	local s = RarityBoxService.new(ReturnRequest, GunRarity)
	s:Init()
	return s
end)



local codeService = LoadModule("CodeService", function()
	local s = CodeService.new()
	s:Init()
	return s
end)



Players.PlayerRemoving:Connect(function(player)
	tycoonService:_OnPlayerRemoving(player)
	playerService:_OnPlayerRemoving(player)
	codeService:_OnPlayerRemoving()
end)