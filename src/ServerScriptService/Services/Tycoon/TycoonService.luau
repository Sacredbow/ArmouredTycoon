local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataTemplate = require(ServerScriptService.DataManager.DataTemplate)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local TycoonClass = require(ServerScriptService.Classes.Tycoon)
local RagdollModule = require(ServerScriptService.Modules.RagdollModule)
local CollisionModule = require(ServerScriptService.Modules.CollisionManager)
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)
local TutorialSignals = require(ReplicatedStorage.Network.TutorialSignals)

local TycoonService = {}
TycoonService.__index = TycoonService

type ConstructionData = {
	PurchasedButtons: { string },
}


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

function TycoonService.new(playerService, purchaseService)
	local self = setmetatable({}, TycoonService)
	self.PlayerService = playerService
	self.PurchaseService = purchaseService
	self.Tycoons = {}
	self.TycoonsByOwner = {}
	return self
end


function TycoonService:_SendAvailableTycoonDoors(player: Player)
	if not waitForProfile(player) then
		return
	end

	if ProfileManager.HasCompletedOnboarding(player) then
		return
	end

	for _, tycoon in ipairs(self.Tycoons) do
		if not tycoon.Owner then
			TutorialSignals.Send(player, "TycoonAvailable", getOwnerDoorPath(tycoon))
		end
	end
end

function TycoonService:_StartOnboardingDoorGuidance()
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			self:_SendAvailableTycoonDoors(player)
		end)
	end

	if self.PlayerAddedConnection then
		self.PlayerAddedConnection:Disconnect()
	end

	self.PlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			self:_SendAvailableTycoonDoors(player)
		end)
	end)
end

function TycoonService:Init()
	self:_SetupRemotes()

	local tycoonsFolder = Diagnostics.requireValue(workspace:FindFirstChild("Tycoons"), "TycoonService", "workspace.Tycoons is required")
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
	self:_StartOnboardingDoorGuidance()
end

function TycoonService:_SetupRemotes()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
	if #self.Tycoons == 0 then
		Diagnostics.report("TycoonService", "No tycoon models were available during initialization; other services will continue loading.")
	end

	local tycoonAction = remotesFolder:FindFirstChild("TycoonAction")
	if not tycoonAction then
		tycoonAction = Instance.new("RemoteFunction")
		tycoonAction.Name = "TycoonAction"
		tycoonAction.Parent = remotesFolder
	end

	Diagnostics.invariant(tycoonAction:IsA("RemoteFunction"), "TycoonService", "Remotes.TycoonAction must be a RemoteFunction");
	(tycoonAction :: RemoteFunction).OnServerInvoke = function(player: Player, action: string)
		if action == "Rebirth" then
			return self:RequestRebirth(player)
		end

		Diagnostics.reject(player, "TycoonAction", `Unknown action: {tostring(action)}`)
		return false, "Unknown tycoon action."
	end
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
		if not tycoon.Owner then 
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

	if self.PlayerService.BuildService then
		self.PlayerService.BuildService:ClearPlayer(player, tycoon)
	end

	tycoon:_ClearSavedConstruction(player)
	tycoon:Cleanup()
	self.TycoonsByOwner[player] = nil
end

function TycoonService:RequestRebirth(player: Player)
	local tycoon = self.TycoonsByOwner[player]
	if not tycoon then
		return false, "Claim a tycoon first."
	end

	if not tycoon:CheckCompletion(tycoon.Buttons) then
		player:SetAttribute("CanRebirth", false)
		return false, "Complete your tycoon before rebirthing."
	end

	self:Rebirth(player)
	return true, "Rebirth complete. Your tycoon has been reset."
end



return TycoonService
