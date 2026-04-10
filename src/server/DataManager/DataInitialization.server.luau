local Players  = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(ServerScriptService.Libraries.ProfileStore)
local DataTemplate = require(ServerScriptService.DataManager.DataTemplate)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)

local Remotes = ReplicatedStorage.Remotes.CharacterStats

local function IsStudio()
	-- Returns if the player is in studio.
	return RunService:IsStudio() and "Test7" or "Game"
end


local PlayerProfileStore = ProfileStore.New(IsStudio(), DataTemplate)
local function Initialize(Player : Player, Profile : typeof(PlayerProfileStore:StartSessionAsync()))
	local leaderstats = Instance.new("Folder", Player)
	leaderstats.Name = "leaderstats"
	
	local Statistics = Instance.new("Folder")
	Statistics.Parent = Player
	Statistics.Name = "Statistics"

	local Cash = Instance.new("IntValue")
	Cash.Parent = leaderstats
	Cash.Name = "Cash"
	Cash.Value = Profile.Data.Cash
	
	local Emerald = Instance.new("IntValue")
	Emerald.Parent = leaderstats
	Emerald.Name = "Emerald"
	Emerald.Value = Profile.Data.Emerald
	
	local Kills = Instance.new("IntValue")
	Kills.Parent = leaderstats
	Kills.Name = "Kills"
	Kills.Value = Profile.Data.Kills



	local Rebirths = Instance.new("IntValue")
	Rebirths.Parent = Statistics
	Rebirths.Name = "Rebirths"
	
	
	Remotes.SynchronizeCash:FireClient(Player, Profile.Data.Cash)
	--Remotes.SynchronizeKills:FireClient(Player, Profile.Data.Kills)
	Remotes.SynchronizeEmerald:FireClient(Player, Profile.Data.Emerald)
    Remotes.SynchronizeRebirths:FireClient(Player, Profile.Data.Rebirths)
	
	
	
	
	
	Cash.Changed:Connect(function(newValue)
		Remotes.SynchronizeCash:FireClient(Player, newValue)
		Profile.Data.Cash = newValue
		
	end)

	Emerald.Changed:Connect(function(newValue)
		Remotes.SynchronizeEmerald:FireClient(Player, newValue)
		Profile.Data.Emerald = newValue

	end)

	--Kills.Changed:Connect(function(newValue)
	--	Remotes.SynchronizeKills:FireClient(Player, newValue)
	--end)
	
	Rebirths.Changed:Connect(function(newValue)
		Remotes.SynchronizeRebirths:FireClient(Player, newValue)
		Profile.Data.Rebirths = newValue

	end)

	
end

-- New profile session
local function OnPlayerAdded(player : Player)
	
	
	local Profile = PlayerProfileStore:StartSessionAsync("Player_".. player.UserId, {
		Cancel = function()
			-- Issue with player getting disconnected, needs to clean itself up.
			return player.Parent ~= Players
		end,
	})
	
	-- Make sure profile exists
	if Profile ~= nil then
		
		Profile:AddUserId(player.UserId) -- GDPR Compliance
		Profile:Reconcile() -- If the template changes in player sessions, fill missing variables
		
		Profile.OnSessionEnd:Connect(function()
			-- Session locking
			-- OnSessionEnd is what going to happen when the cancel function runs, or manually stopped, prevent duplications
			ProfileManager.Profiles[player] = nil	
			player:Kick("An error occured with your Profile data, please rejoin or report this in the communications server.")
		end)
		
		if player.Parent == Players then
			ProfileManager.Profiles[player] = Profile
			Initialize(player, Profile)
			
		else
			Profile:EndSession()
			-- Same thing with OnSessionEnd
		end
	else
		-- Server shutting down, update.
		player:Kick("An error occured with your Profile data, please rejoin or report this in the communications server.")
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(OnPlayerAdded, player)
	-- Player joins the game before the script runs
	
end

local function OnPlayerRemoving(player : Player)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end
	
	profile:EndSession()
	ProfileManager.Profiles[player] = nil
end

Players.PlayerAdded:Connect(OnPlayerAdded)

Players.PlayerRemoving:Connect(OnPlayerRemoving)