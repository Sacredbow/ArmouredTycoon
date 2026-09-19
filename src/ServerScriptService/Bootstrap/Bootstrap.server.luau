--!strict
--[[
	@class Bootstrap

	@desc
	Initializes all server-side services in dependency order.
	Uses LoadModule wrapper for safe initialization with error logging.
]]

--// Services

const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Players = game:GetService("Players")

--// Modules

const Packets = require(ReplicatedStorage.Network.Packets)
const Assets = ReplicatedStorage:WaitForChild("Assets")

const PlayerService = require(ServerScriptService.Services.Tycoon.PlayerService)
const TycoonService = require(ServerScriptService.Services.Tycoon.TycoonService)
const PurchaseService = require(ServerScriptService.Services.Commerce.CommerceService)
const EnvironmentService = require(ServerScriptService.Services.World.EnvironmentService)
const BuildAssemble = require(ReplicatedStorage.Libraries.BuildAssemble)
const RarityBoxService = require(ServerScriptService.Services.World.RarityBoxService)
const LeaderboardService = require(ServerScriptService.Services.World.LeaderboardService)
const KOTHService = require(ServerScriptService.Services.World.KOTHService)
const CodeService = require(ServerScriptService.Services.Commerce.CodeService)
const InventoryServer = require(ServerScriptService.Gameplay.Inventory.InventoryServer)

--// Internal Utilities

local function LoadModule(Name: string, Loader: () -> any)
	local Start = os.clock()
	local Succeeded, Result = xpcall(Loader, debug.traceback)
	if not Succeeded then
		warn(`[Bootstrap.{Name}] Initialization failed:\n{Result}`)
		return nil
	end
	local Elapsed = math.round((os.clock() - Start) * 1000) / 1000
	warn(string.format("[Modules] Loaded %s, took %.3f seconds", Name, Elapsed))
	return Result
end

--// Module Initialization

local PlayerSvc = LoadModule("PlayerService", function()
	local S = PlayerService.new()
	S:Init()
	return S
end)

if not PlayerSvc then
	error("[Bootstrap] PlayerService failed to initialize — cannot continue.")
end

local PurchaseSvc = LoadModule("PurchaseService", function()
	local S = PurchaseService.new(PlayerSvc)
	S:Init()
	return S
end)

if not PurchaseSvc then
	error("[Bootstrap] PurchaseService failed to initialize — cannot continue.")
end

local TycoonSvc = LoadModule("TycoonService", function()
	local S = TycoonService.new(PlayerSvc, PurchaseSvc)
	S:Init()
	return S
end)

if not TycoonSvc then
	error("[Bootstrap] TycoonService failed to initialize — cannot continue.")
end

PlayerSvc.TycoonService = TycoonSvc

local _EnvironmentSvc = LoadModule("EnvironmentService", function()
	local S = EnvironmentService.new({
		LightingPackage = Assets.Lighting,
		Props = workspace.Map.Props,
		Packets = Packets,
		BuildAssemble = BuildAssemble,
	})
	S:Init()
	return S
end)

local _RarityBoxSvc = LoadModule("RarityBoxService", function()
	local S = RarityBoxService.new(Packets)
	S:Init()
	return S
end)

local _LeaderboardSvc = LoadModule("LeaderboardService", function()
	local S = LeaderboardService.new()
	S:Init()
	return S
end)

local _KOTHSvc = LoadModule("KOTHService", function()
	local S = KOTHService.new()
	S:Init()
	return S
end)

local _InventorySvc = LoadModule("InventoryServer", function()
	local S = InventoryServer.new()
	S:Start()
	return S
end)

local CodeSvc = LoadModule("CodeService", function()
	local S = CodeService.new()
	S:Init()
	return S
end)

--// Cleanup

Players.PlayerRemoving:Connect(function(Player)
	TycoonSvc:_OnPlayerRemoving(Player)
	PlayerSvc:_OnPlayerRemoving(Player)
	CodeSvc:_OnPlayerRemoving(Player)
end)
