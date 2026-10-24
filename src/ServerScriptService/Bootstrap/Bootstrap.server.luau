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
--// Modules

const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const Assets = ReplicatedStorage:WaitForChild("Assets")
const PlayerService = require(ServerScriptService.Game.Tycoon.PlayerService)
const TycoonService = require(ServerScriptService.Game.Tycoon.TycoonService)
const PurchaseService = require(ServerScriptService.Services.Commerce.CommerceService)
const EnvironmentService = require(ServerScriptService.Services.World.EnvironmentService)
const BuildAssemble = require(ReplicatedStorage.Shared.Game.Tycoon.Building.BuildEffect)
const RarityBoxService = require(ServerScriptService.Services.World.RarityBoxService)
const LeaderboardService = require(ServerScriptService.Services.World.LeaderboardService)
const KOTHService = require(ServerScriptService.Services.World.KOTHService)
const CodeService = require(ServerScriptService.Services.Commerce.CodeService)
const InventoryServer = require(ServerScriptService.Gameplay.Inventory.InventoryServer)
const BuildService = require(ServerScriptService.Game.Tycoon.Building.BuildingService)
const NukeService = require(ServerScriptService.Services.World.NukeService)
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
	PlayerService.Init()
	return PlayerService
end)

if not PlayerSvc then
	error("[Bootstrap] PlayerService failed to initialize — cannot continue.")
end

local PurchaseSvc = LoadModule("PurchaseService", function()
	PurchaseService.Init()
	return PurchaseService
end)

if not PurchaseSvc then
	error("[Bootstrap] PurchaseService failed to initialize — cannot continue.")
end

local BuildSvc = LoadModule("BuildService", function()
	BuildService.Init()
	return BuildService
end)
if not BuildSvc then
	error("[Bootstrap] BuildService failed to initialize — cannot continue.")
end
TycoonService.Init(PurchaseSvc, BuildSvc)

local _NukeSvc = LoadModule("NukeService", function()
	NukeService.Init(BuildSvc)
	return NukeService
end)

local _EnvironmentSvc = LoadModule("EnvironmentService", function()
	EnvironmentService.Configure({
		LightingPackage = Assets.Lighting,
		Props = workspace.Map.Props,
		Packets = Packets,
		BuildAssemble = BuildAssemble,
	})
	EnvironmentService.Start()
	return EnvironmentService
end)

local _RarityBoxSvc = LoadModule("RarityBoxService", function()
	RarityBoxService.Init(Packets)
	return RarityBoxService
end)

local _LeaderboardSvc = LoadModule("LeaderboardService", function()
	LeaderboardService.Init()
	return LeaderboardService
end)

local _KOTHSvc = LoadModule("KOTHService", function()
	KOTHService.Init()
	return KOTHService
end)

local _InventorySvc = LoadModule("InventoryServer", function()
	InventoryServer.Start()
	return InventoryServer
end)

local CodeSvc = LoadModule("CodeService", function()
	CodeService.Init()
	return CodeService
end)
