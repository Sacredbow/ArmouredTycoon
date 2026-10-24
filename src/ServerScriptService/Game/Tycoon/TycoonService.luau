--!strict
-- Tycoon lifecycle and network adapter. Tycoon gameplay is processed by ECS systems.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataTemplate = require(ServerScriptService.DataManager.DataTemplate)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Factory = require(ServerScriptService.Game.Tycoon.TycoonFactory)
local TycoonRuntime = require(ServerScriptService.Game.Tycoon.TycoonCoordinator)
local TycoonQueries = require(ServerScriptService.Game.Tycoon.TycoonQueries)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)

local TycoonService = {}
local Initialized = false
local PlayerObserverStop: (() -> ())?
local PlayerCleanupObserverStop: (() -> ())?

local function WaitForProfile(Player: Player): boolean
	local Deadline = os.clock() + 20
	while Player.Parent == Players and not ProfileManager.Profiles[Player] and os.clock() < Deadline do
		task.wait(0.25)
	end
	return ProfileManager.Profiles[Player] ~= nil
end

local function ClearSavedConstruction(Player: Player)
	local Profile = ProfileManager.Profiles[Player]
	if not Profile then
		return
	end
	Profile.Data.TycoonConstruction = Profile.Data.TycoonConstruction or { PurchasedButtons = {} }
	Profile.Data.TycoonConstruction.PurchasedButtons = {}
end

local function SendAvailableTycoonDoors(Player: Player)
	if not WaitForProfile(Player) or ProfileManager.HasCompletedOnboarding(Player) then
		return
	end
	for Entity, State in ECS.world:query(ECS.Components.TycoonState) do
		if State.active ~= false and not State.owner then
			local Model = Factory.GetModel(Entity)
			if Model then
				Packets.packets.Tutorial.sendTo({
					type = "TycoonAvailable",
					target = string.format("%s:MainItems:OwnerDoor:Door", Model.Name),
				}, Player)
			end
		end
	end
end

local function Rebirth(Player: Player, BuildService: any)
	local Entity = TycoonQueries.FindOwnedTycoon(Player)
	ProfileManager.AddRebirths(Player, 1)
	ProfileManager.SetCash(Player, DataTemplate.Cash)
	if not Entity then
		ClearSavedConstruction(Player)
		return
	end
	if BuildService then
		BuildService:ClearPlayer(Player, Entity)
	end
	TycoonRuntime.Cleanup(Entity, BuildService)
end

local function RequestRebirth(Player: Player, BuildService: any)
	local Entity = TycoonQueries.FindOwnedTycoon(Player)
	if not Entity then
		return false, "Claim a tycoon first."
	end
	if not TycoonRuntime.CheckCompletion(Entity) then
		local PlayerEntity = TycoonQueries.FindPlayerEntity(Player)
		if PlayerEntity then
			ECS.world:set(PlayerEntity, ECS.Components.CanRebirth, false)
		end
		return false, "Complete your tycoon before rebirthing."
	end
	Rebirth(Player, BuildService)
	return true, "Rebirth complete. Your tycoon has been reset."
end

local function SetupRemotes(BuildService: any)
	NetworkGuard.Query(Packets.queries.TycoonAction, "TycoonAction", {
		Rate = 4,
		Burst = 6,
		Validate = function(Request)
			return type(Request) == "table" and Request.action == "Rebirth"
		end,
	}, function(Request, Player: Player?)
		if not Player then
			return { success = false, message = "Player unavailable." }
		end
		local Success, Message = RequestRebirth(Player, BuildService)
		return { success = Success == true, message = tostring(Message) }
	end)
end

function TycoonService.Init(PurchaseService: any, BuildService: any)
	if Initialized then
		return
	end
	Initialized = true
	SetupRemotes(BuildService)

	PlayerCleanupObserverStop = Observers.observePlayer(function(Player: Player)
		return function()
			local Entity = TycoonQueries.FindOwnedTycoon(Player)
			if Entity then
				ClearSavedConstruction(Player)
				TycoonRuntime.Cleanup(Entity, BuildService)
			end
		end
	end)

	local TycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not TycoonsFolder then
		warn("[TycoonService] workspace.Tycoons is required but not found")
		return
	end
	for _, TycoonModel in TycoonsFolder:GetChildren() do
		if TycoonModel:IsA("Model") then
			local Entity = Factory.Spawn(TycoonModel)
			TycoonRuntime.Init(Entity, PurchaseService, BuildService)
			local DestroyingConnection
			DestroyingConnection = TycoonModel.Destroying:Connect(function()
				if DestroyingConnection then
					DestroyingConnection:Disconnect()
				end
				TycoonRuntime.Destroy(Entity)
				Factory.Destroy(Entity)
			end)
		end
	end

	if not PlayerObserverStop then
		PlayerObserverStop = Observers.observePlayer(function(Player: Player)
			task.defer(function()
				SendAvailableTycoonDoors(Player)
			end)
		end)
	end
end

return TycoonService
