local Players  = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(ServerScriptService.Libraries.ProfileStore)
local DataTemplate = require(ServerScriptService.DataManager.DataTemplate)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local Packets = require(ReplicatedStorage.Network.Packets)
local Janitor = require(ReplicatedStorage.Packages.janitor)


local function IsStudio()
	-- Returns if the player is in studio.
	return RunService:IsStudio() and "Test7" or "live44"
end


local PlayerProfileStore = ProfileStore.New(IsStudio(), DataTemplate)
local SessionJanitors = {}

local function syncStat(player: Player, stat: string, value: number)
	Packets.packets.StatSync.sendTo({
		stat = stat,
		value = value,
	}, player)
end

local function releasePlayerRuntime(player: Player)
	local janitor = SessionJanitors[player]
	if janitor then
		janitor:Destroy()
		SessionJanitors[player] = nil
	end

	ProfileManager.ReleaseProfileState(player)
end

local function Initialize(Player : Player, Profile : typeof(PlayerProfileStore:StartSessionAsync()))
	local oldJanitor = SessionJanitors[Player]
	if oldJanitor then
		oldJanitor:Destroy()
	end

	local sessionJanitor = Janitor.new()
	SessionJanitors[Player] = sessionJanitor

	Profile.Data.Level = Profile.Data.Level or 1
	Profile.Data.Experience = Profile.Data.Experience or 0
	Profile.Data.Onboarding = Profile.Data.Onboarding == true
	Profile.Data.LastDailyReward = Profile.Data.LastDailyReward or 0
	Profile.Data.QuestCycles = Profile.Data.QuestCycles or {
		DailyStart = 0,
		WeeklyStart = 0,
	}
	Profile.Data.Quests = Profile.Data.Quests or {}
	Profile.Data.Quests.QueensWish = Profile.Data.Quests.QueensWish or {
		Progress = 0,
		Completed = false,
		Claimed = false,
	}
	Profile.Data.Quests.PaydayPatrol = Profile.Data.Quests.PaydayPatrol or {
		Progress = 0,
		Completed = false,
		Claimed = false,
	}

	local leaderstats = Instance.new("Folder", Player)
	leaderstats.Name = "leaderstats"

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
	Rebirths.Parent = leaderstats
	Rebirths.Name = "Rebirths"
	Rebirths.Value = Profile.Data.Rebirths or 0
	
	local Level = Instance.new("IntValue")
	Level.Parent = leaderstats
	Level.Name = "Level"
	Level.Value = Profile.Data.Level or 1
	syncStat(Player, "Cash", Profile.Data.Cash)
	syncStat(Player, "Kills", Profile.Data.Kills)
	syncStat(Player, "Emerald", Profile.Data.Emerald)
	syncStat(Player, "Rebirths", Profile.Data.Rebirths)
	syncStat(Player, "Level", Profile.Data.Level or 1)
	syncStat(Player, "Experience", Profile.Data.Experience or 0)
	ProfileManager.SyncProfileState(Player)
	ProfileManager.BindQuestTracking(Player)
	
	
	
	
	
	sessionJanitor:Add(Cash.Changed:Connect(function(newValue)
		syncStat(Player, "Cash", newValue)
		Profile.Data.Cash = newValue
		
	end), "Disconnect", "CashChanged")

	sessionJanitor:Add(Emerald.Changed:Connect(function(newValue)
		syncStat(Player, "Emerald", newValue)
		Profile.Data.Emerald = newValue

	end), "Disconnect", "EmeraldChanged")

	sessionJanitor:Add(Kills.Changed:Connect(function(newValue)
		Profile.Data.Kills = newValue
		syncStat(Player, "Kills", newValue)
	end), "Disconnect", "KillsChanged")

	sessionJanitor:Add(Rebirths.Changed:Connect(function(newValue)
		Profile.Data.Rebirths = newValue
		syncStat(Player, "Rebirths", newValue)
	end), "Disconnect", "RebirthsChanged")

	sessionJanitor:Add(Level.Changed:Connect(function(newValue)
		Profile.Data.Level = newValue
		syncStat(Player, "Level", newValue)
	end), "Disconnect", "LevelChanged")

	return sessionJanitor
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
		
		local function onSessionEnd()
			-- Session locking
			-- OnSessionEnd is what going to happen when the cancel function runs, or manually stopped, prevent duplications
			releasePlayerRuntime(player)
			ProfileManager.Profiles[player] = nil	
			player:Kick("An error occured with your Profile data, please rejoin or report this in the communications server.")
		end
		
		if player.Parent == Players then
			ProfileManager.Profiles[player] = Profile
			local sessionJanitor = Initialize(player, Profile)
			sessionJanitor:Add(Profile.OnSessionEnd:Connect(onSessionEnd), "Disconnect", "ProfileSessionEnded")
			
		else
			Profile:EndSession()
			releasePlayerRuntime(player)
			-- Same thing with OnSessionEnd
		end
	else
		-- Server shutting down, update.
		player:Kick("An error occured with your Profile data, please rejoin or report this in the communications server.")
	end
end

for _, player in Players:GetPlayers() do
	task.defer(OnPlayerAdded, player)
	-- Player joins the game before the script runs
	
end

local function OnPlayerRemoving(player : Player)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end
	
	profile:EndSession()
	releasePlayerRuntime(player)
	ProfileManager.Profiles[player] = nil
end

Players.PlayerAdded:Connect(OnPlayerAdded)

Players.PlayerRemoving:Connect(OnPlayerRemoving)
