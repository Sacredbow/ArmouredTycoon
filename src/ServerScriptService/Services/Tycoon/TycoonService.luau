--!strict
--[[
	@class TycoonService

	@desc
	Orchestrates tycoon lifecycle — initializes all Tycoon instances,
	handles player rebirth, owner registration, and tutorial onboarding
	for unclaimed tycoon doors.
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const DataTemplate = require(ServerScriptService.DataManager.DataTemplate)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const TycoonClass = require(ServerScriptService.Classes.Tycoon)
const RagdollModule = require(ServerScriptService.Modules.RagdollModule)
const CollisionModule = require(ServerScriptService.Modules.CollisionManager)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
const Packets = require(ReplicatedStorage.Network.Packets)

--// Types

type ConstructionData = {
	PurchasedButtons: { string },
}

--// Module

local TycoonService = {}
TycoonService.__index = TycoonService

local function waitForProfile(player: Player): boolean
	local deadline = os.clock() + 20
	while player.Parent == Players and not ProfileManager.Profiles[player] and os.clock() < deadline do
		task.wait(0.25)
	end

	return ProfileManager.Profiles[player] ~= nil
end

local function getOwnerDoorPath(tycoon): string
	return `{tycoon.Model.Name}:MainItems:OwnerDoor:Door`
end

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

function TycoonService.new(playerService: any, purchaseService: any): TycoonServiceInstance
	local self = setmetatable({}, TycoonService) :: TycoonServiceInstance
	self.PlayerService = playerService
	self.PurchaseService = purchaseService
	self.Tycoons = {}
	self.TycoonsByOwner = {}
	return self
end

function TycoonService._SendAvailableTycoonDoors(self: TycoonServiceInstance, player: Player)
	if not waitForProfile(player) then
		return
	end

	if ProfileManager.HasCompletedOnboarding(player) then
		return
	end

	for _, tycoon in ipairs(self.Tycoons) do
		if not tycoon.Owner then
			Packets.packets.Tutorial.sendTo({ ["type"] = "TycoonAvailable", target = getOwnerDoorPath(tycoon) }, player)
		end
	end
end

function TycoonService._StartOnboardingDoorGuidance(self: TycoonServiceInstance)
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			self._SendAvailableTycoonDoors(self, player)
		end)
	end

	if self.PlayerAddedConnection then
		self.PlayerAddedConnection:Disconnect()
	end

	self.PlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			self._SendAvailableTycoonDoors(self, player)
		end)
	end)
end

function TycoonService.Init(self: TycoonServiceInstance)
	self._SetupRemotes(self)

	local tycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not tycoonsFolder then
		warn("[TycoonService] workspace.Tycoons is required but not found; tycoons will not initialize")
		return
	end
	print("Initializing tycoons...")

	for _, tycoonModel in ipairs(tycoonsFolder:GetChildren()) do
		if tycoonModel:IsA("Model") then
			local tycoon =
				TycoonClass.new(tycoonModel, self.PlayerService, self.PurchaseService, RagdollModule, CollisionModule)
			tycoon:Init()
			table.insert(self.Tycoons, tycoon)
			print("Setup complete:", tycoonModel.Name)
		end
	end

	print("All tycoons initialized!")
	self._StartOnboardingDoorGuidance(self)
end

function TycoonService._SetupRemotes(self: TycoonServiceInstance)
	if #self.Tycoons == 0 then
		warn("[TycoonService] No tycoon models were available during initialization; other services will continue loading.")
	end

	Packets.queries.TycoonAction.listen(function(request, player: Player?)
		if not player then
			return { success = false, message = "Player unavailable." }
		end

		if request.action == "Rebirth" then
			local success, message = self.RequestRebirth(self, player)
			return { success = success == true, message = tostring(message) }
		end

		warn(`[TycoonService] {tostring(player)} sent unknown action: {tostring(request.action)}`)
		return { success = false, message = "Unknown tycoon action." }
	end)
end
function TycoonService.RegisterOwner(self: TycoonServiceInstance, player, tycoon)
	self.TycoonsByOwner[player] = tycoon
end

function TycoonService.GetTycoonForPlayer(self: TycoonServiceInstance, player)
	return self.TycoonsByOwner[player]
end

function TycoonService.GetAllTycoons(self: TycoonServiceInstance)
	return self.Tycoons
end

function TycoonService.FindUnclaimedTycoon(self: TycoonServiceInstance) 
	for _, tycoon in ipairs(self.Tycoons) do
		if not tycoon.Owner then
			return tycoon
		end
	end
	return nil
end

function TycoonService._OnPlayerRemoving(self: TycoonServiceInstance, player)
	local tycoon = self.TycoonsByOwner[player]
	if tycoon then
		tycoon:Cleanup()
		self.TycoonsByOwner[player] = nil
	end
end

function TycoonService.Rebirth(self: TycoonServiceInstance, player: Player, rebirthAmount: number?)
	local tycoon = self.TycoonsByOwner[player]
	local amountToAward = rebirthAmount or 1

	ProfileManager.AddRebirths(player, amountToAward)
	ProfileManager.SetCash(player, DataTemplate.Cash)

	if not tycoon then
		clearSavedConstruction(player)
		warn(`[TycoonService] Rebirth applied for {player.Name} without an active tycoon`)
		return
	end

	if self.PlayerService.BuildService then
		self.PlayerService.BuildService:ClearPlayer(player, tycoon)
	end

	tycoon:_ClearSavedConstruction(player)
	tycoon:Cleanup()
	self.TycoonsByOwner[player] = nil
end

function TycoonService.RequestRebirth(self: TycoonServiceInstance, player: Player)
	local tycoon = self.TycoonsByOwner[player]
	if not tycoon then
		return false, "Claim a tycoon first."
	end

	if not tycoon:CheckCompletion(tycoon.Buttons) then
		PlayerRuntimeState.SetCanRebirth(player, false)
		return false, "Complete your tycoon before rebirthing."
	end

	self.Rebirth(self, player)
	return true, "Rebirth complete. Your tycoon has been reset."
end

-- ================================================================================
-- TYPE DEFINITION
-- ================================================================================
-- TycoonServiceInstance is the type for a constructed TycoonService object
-- (returned by TycoonService.new). It combines:
--   1. All methods defined on TycoonService (via the metatable)
--   2. Instance properties set in TycoonService.new()

export type TycoonServiceInstance = typeof(setmetatable({}, TycoonService)) & {
	PlayerService: any,
	PurchaseService: any,
	Tycoons: { TycoonClass.TycoonInstance },
	TycoonsByOwner: { [Player]: TycoonClass.TycoonInstance },
	PlayerAddedConnection: RBXScriptConnection?,
}

return TycoonService
