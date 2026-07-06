local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
require(ReplicatedStorage.Network.Packets)

local Assets = ReplicatedStorage:WaitForChild("Assets")

local PlayerService =   require(ServerScriptService.Services.Tycoon.PlayerService)
local TycoonService = require(ServerScriptService.Services.Tycoon.TycoonService)
-- BuildService is intentionally paused while its placement flow is under development.
-- local BuildService = require(ServerScriptService.Services.Tycoon.BuildService)
local PurchaseService = require(ServerScriptService.Services.Commerce.CommerceService)
local EnvironmentService = require(ServerScriptService.Services.World.EnvironmentService)
local BuildAssemble = require(ServerScriptService.Utilities.BuildAssemble)
local RarityBoxService = require(ServerScriptService.Services.World.RarityBoxService)
local LeaderboardService = require(ServerScriptService.Services.World.LeaderboardService)
local KOTHService = require(ServerScriptService.Services.World.KOTHService)
local CodeService = require(ServerScriptService.Services.Commerce.CodeService)
local InventoryServer = require(ServerScriptService.Gameplay.Inventory.InventoryServer)
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)
local ClientSignals = require(ReplicatedStorage.Network.ClientSignals)


local function LoadModule(name: string, loader: () -> any)
	local start = os.clock()
	local succeeded, result = xpcall(loader, debug.traceback)
	if not succeeded then
		Diagnostics.fatal(`Bootstrap.{name}`, `Initialization failed:\n{result}`)
	end
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

-- local buildService = LoadModule("BuildService", function()
-- 	local s = BuildService.new(playerService, tycoonService)
-- 	s:Init()
-- 	return s
-- end)
-- playerService.BuildService = buildService

local _environmentService = LoadModule("EnvironmentService", function()
	local s = EnvironmentService.new({
		LightingPackage = Assets.Lighting,
		Props = workspace.Map.Props,
		ClientSignals = ClientSignals,
		BuildAssemble = BuildAssemble
	})
	s:Init()
	return s
end)

local _rarityBoxService = LoadModule("RarityBoxService", function()
	local s = RarityBoxService.new(ClientSignals)
	s:Init()
	return s
end)

local _leaderboardService = LoadModule("LeaderboardService", function()
	local s = LeaderboardService.new()
	s:Init()
	return s
end)

local _kothService = LoadModule("KOTHService", function()
	local s = KOTHService.new()
	s:Init()
	return s
end)

local _inventory = LoadModule("InventoryServer", function()
	local s = InventoryServer.new()
	s:Start()
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
	codeService:_OnPlayerRemoving(player)
end)
