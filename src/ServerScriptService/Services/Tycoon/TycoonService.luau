--!strict
--[[
	TycoonService is the ECS orchestration boundary. It owns no Tycoon
	instances: models are spawned into the shared ECS world and all gameplay
	commands address numeric entity IDs.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataTemplate = require(ServerScriptService.DataManager.DataTemplate)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
local Packets = require(ReplicatedStorage.Network.Packets)
local ECS = require(ReplicatedStorage.ECS)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Factory = require(ServerScriptService.ECS.TycoonFactory)
local TycoonRuntime = require(ServerScriptService.ECS.TycoonRuntime)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)

local TycoonService = {}

local function waitForProfile(player: Player): boolean
	local deadline = os.clock() + 20
	while player.Parent == Players and not ProfileManager.Profiles[player] and os.clock() < deadline do
		task.wait(0.25)
	end
	return ProfileManager.Profiles[player] ~= nil
end

local function clearSavedConstruction(player: Player)
	local profile = ProfileManager.Profiles[player]
	if not profile then return end
	profile.Data.TycoonConstruction = profile.Data.TycoonConstruction or {PurchasedButtons = {}}
	profile.Data.TycoonConstruction.PurchasedButtons = {}
end

function TycoonService.create(playerService: any, purchaseService: any)
	local self = {}
	self.PlayerService = playerService
	self.PurchaseService = purchaseService
	self.Initialized = false
	self.PlayerObserverStop = nil
	self.PlayerCleanupObserverStop = nil
	return self
end

function TycoonService:_sendAvailableTycoonDoors(player: Player)
	if not waitForProfile(player) or ProfileManager.HasCompletedOnboarding(player) then return end
	for entity, state in ECS.world:query(ECS.Components.TycoonState) do
		if state.active ~= false and not state.owner then
			local model = Factory.getModel(entity)
			if model then
				Packets.packets.Tutorial.sendTo({
					type = "TycoonAvailable",
					target = string.format("%s:MainItems:OwnerDoor:Door", model.Name),
				}, player)
			end
		end
	end
end

function TycoonService:_startOnboardingDoorGuidance()
	if self.PlayerObserverStop then
		return
	end

	self.PlayerObserverStop = Observers.observePlayer(function(player: Player)
		task.defer(function()
			self:_sendAvailableTycoonDoors(player)
		end)
	end)
end

function TycoonService:Init()
	if self.Initialized then
		return
	end
	self.Initialized = true
	self:_setupRemotes()
	self.PlayerCleanupObserverStop = Observers.observePlayer(function(player: Player)
		return function()
			self:_onPlayerRemoving(player)
		end
	end)
	local tycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not tycoonsFolder then
		warn("[TycoonService] workspace.Tycoons is required but not found")
		return
	end
	for _, tycoonModel in tycoonsFolder:GetChildren() do
		if tycoonModel:IsA("Model") then
			local entity = Factory.spawn(tycoonModel)

			TycoonRuntime.init(entity, self.PlayerService, self.PurchaseService, self.PlayerService.BuildService)
			local destroyingConnection
			destroyingConnection = tycoonModel.Destroying:Connect(function()
				if destroyingConnection then
					destroyingConnection:Disconnect()
				end
				TycoonRuntime.destroy(entity)
				Factory.destroy(entity)
			end)
		end
	end
	self:_startOnboardingDoorGuidance()
end

function TycoonService:_setupRemotes()
	NetworkGuard.Query(Packets.queries.TycoonAction, "TycoonAction", {
		Rate = 4,
		Burst = 6,
		Validate = function(request)
			return type(request) == "table" and request.action == "Rebirth"
		end,
	}, function(request, player: Player?)
		if not player then return {success = false, message = "Player unavailable."} end
		local success, message = self:RequestRebirth(player)
		return {success = success == true, message = tostring(message)}
	end)
end

function TycoonService:RegisterOwner(player: Player, entity: number)
	local state = Factory.getState(entity)
	if state and state.owner ~= player then
		Factory.setOwner(entity, player)
	end
end

function TycoonService:GetTycoonForPlayer(player: Player): number?
	for entity, state in ECS.world:query(ECS.Components.TycoonState) do
		if state.active ~= false and state.owner == player then return entity end
	end
	return nil
end

function TycoonService:GetTycoonModel(entity: number): Model?
	return Factory.getModel(entity)
end

function TycoonService:GetAllTycoons(): {number}
	local result = {}
	for entity, state in ECS.world:query(ECS.Components.TycoonState) do
		if state.active ~= false then table.insert(result, entity) end
	end
	return result
end

function TycoonService:FindUnclaimedTycoon(): number?
	for entity, state in ECS.world:query(ECS.Components.TycoonState) do
		if state.active ~= false and not state.owner then return entity end
	end
	return nil
end

function TycoonService:_onPlayerRemoving(player: Player)
	local entity = self:GetTycoonForPlayer(player)
	if entity then
		clearSavedConstruction(player)
		TycoonRuntime.cleanup(entity, self.PlayerService, self.PlayerService.BuildService)
	end
end

function TycoonService:Rebirth(player: Player, rebirthAmount: number?)
	local entity = self:GetTycoonForPlayer(player)
	ProfileManager.AddRebirths(player, rebirthAmount or 1)
	ProfileManager.SetCash(player, DataTemplate.Cash)
	if not entity then
		clearSavedConstruction(player)
		return
	end
	if self.PlayerService.BuildService then
		self.PlayerService.BuildService:ClearPlayer(player, entity)
	end
	TycoonRuntime.cleanup(entity, self.PlayerService, self.PlayerService.BuildService)
end

function TycoonService:RequestRebirth(player: Player)
	local entity = self:GetTycoonForPlayer(player)
	if not entity then return false, "Claim a tycoon first." end
	if not TycoonRuntime.checkCompletion(entity) then
		PlayerRuntimeState.SetCanRebirth(player, false)
		return false, "Complete your tycoon before rebirthing."
	end
	self:Rebirth(player)
	return true, "Rebirth complete. Your tycoon has been reset."
end

return TycoonService