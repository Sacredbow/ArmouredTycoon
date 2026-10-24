local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileManager = {}
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
local Janitor = require(ReplicatedStorage.Packages.janitor)
local QuestOptions = require(ReplicatedStorage.Shared.Game.Progression.QuestOptions)
local QuestProgression = require(ServerScriptService.Gameplay.Progression.QuestProgression)
local SoundManager = require(ServerScriptService.Utilities.SoundManager)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)

-- Store profiles from the Profile Store.

ProfileManager.Profiles = {}
ProfileManager.QuestTrackingJanitors = {}

local DAILY_COOLDOWN = QuestOptions.DailyCooldown
local function copyQuestState(quests: { [string]: any }): { [string]: any }
	local copied = {}
	for questId, quest in quests do
		copied[questId] = if typeof(quest) == "table" then table.clone(quest) else quest
	end
	return copied
end

function ProfileManager.GetRequiredExperience(level: number): number
	return math.floor(120 * (1.18 ^ math.max(level - 1, 0)))
end

local function syncStat(player: Player, stat: string, value: number)
	Packets.packets.StatSync.sendTo({
		stat = stat,
		value = math.floor(value),
	}, player)
end

local function buildProfileState(player: Player)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return nil
	end

	QuestProgression.ensure(profile)

	local data = profile.Data
	local now = os.time()
	local quests = data.Quests or {}
	local dailyQuestSecondsRemaining, weeklyQuestSecondsRemaining = QuestProgression.getTimers(profile, now)

	return {
		level = data.Level or 1,
		experience = data.Experience or 0,
		requiredExperience = ProfileManager.GetRequiredExperience(data.Level or 1),
		onboarding = data.Onboarding == true,
		dailyReadyAt = math.max((data.LastDailyReward or 0) + DAILY_COOLDOWN, now),
		dailySecondsRemaining = math.max(0, ((data.LastDailyReward or 0) + DAILY_COOLDOWN) - now),
		dailyQuestSecondsRemaining = dailyQuestSecondsRemaining,
		weeklyQuestSecondsRemaining = weeklyQuestSecondsRemaining,
		quests = copyQuestState(quests),
	}
end

local function encodeProfileState(state: { [string]: any }): string?
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, state)
	if not ok then
		return nil
	end
	return encoded
end

function ProfileManager.SyncProfileState(player: Player)
	local state = buildProfileState(player)
	if not state then
		return
	end

	local payload = encodeProfileState(state)
	if not payload then
		warn(("[ProfileManager] Failed to encode profile state for %s"):format(player.Name))
		return
	end

	Packets.packets.ProfileState.sendTo({ payload = payload }, player)
end

function ProfileManager.ReleaseProfileState(player: Player)
	local questJanitor = ProfileManager.QuestTrackingJanitors[player]
	if questJanitor then
		questJanitor:Destroy()
		ProfileManager.QuestTrackingJanitors[player] = nil
	end
end
local function addQuestProgress(player: Player, metric: string, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	if QuestProgression.addProgress(profile, metric, amount) then
		ProfileManager.SyncProfileState(player)
	end
end

local function getStatisticValue(player: Player, folderName: string, statName: string): IntValue?
	local folder = player:FindFirstChild(folderName)
	if not folder then
		return nil
	end

	local stat = folder:FindFirstChild(statName)
	if stat and stat:IsA("IntValue") then
		return stat
	end

	return nil
end

-- Adds Cash to the catorgized player.
function ProfileManager.AddCash(player: Player, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end
	profile.Data.Cash += amount
	local cashStat = getStatisticValue(player, "leaderstats", "Cash")
	if cashStat then
		cashStat.Value = profile.Data.Cash
	end
	if amount > 0 then
		addQuestProgress(player, "CashEarned", amount)
	end
end

function ProfileManager.SetCash(player: Player, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Cash = amount
	local cashStat = getStatisticValue(player, "leaderstats", "Cash")
	if cashStat then
		cashStat.Value = amount
	end
end

-- Adds Emerald to the catorgized player.
function ProfileManager.AddEmerald(player: Player, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Emerald += amount
	local emeraldStat = getStatisticValue(player, "leaderstats", "Emerald")
	if emeraldStat then
		emeraldStat.Value = profile.Data.Emerald
	end
	if amount > 0 then
		addQuestProgress(player, "EmeraldEarned", amount)
	end
end

function ProfileManager.AddExperience(player: Player, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Level = profile.Data.Level or 1
	profile.Data.Experience = (profile.Data.Experience or 0) + math.max(0, math.floor(amount))
	addQuestProgress(player, "ExperienceEarned", amount)

	local oldLevel = profile.Data.Level

	while profile.Data.Experience >= ProfileManager.GetRequiredExperience(profile.Data.Level) do
		profile.Data.Experience -= ProfileManager.GetRequiredExperience(profile.Data.Level)
		profile.Data.Level += 1
	end

	syncStat(player, "Level", profile.Data.Level)
	syncStat(player, "Experience", profile.Data.Experience)
	if profile.Data.Level > oldLevel then
		SoundManager.PlaySound("LevelUp")
	end
	ProfileManager.SyncProfileState(player)
end

-- Adds Kills to the catorgorized player.
function ProfileManager.AddKills(player: Player, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Kills += amount
	local killsStat = getStatisticValue(player, "leaderstats", "Kills")
	if killsStat then
		killsStat.Value = profile.Data.Kills
	end

	addQuestProgress(player, "Kill", amount)
end

-- Adds Rebirths to the catorgorized player.
function ProfileManager.AddRebirths(player: Player, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Rebirths += amount
	local rebirthsStat = getStatisticValue(player, "leaderstats", "Rebirths")
	if rebirthsStat then
		rebirthsStat.Value = profile.Data.Rebirths
	else
		Packets.packets.StatSync.sendTo({
			stat = "Rebirths",
			value = profile.Data.Rebirths,
		}, player)
	end
	ProfileManager.AddExperience(player, amount * 600)
	addQuestProgress(player, "Rebirth", amount)
end

function ProfileManager.ClaimQuest(player: Player, questId: string)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return false, "Profile unavailable."
	end

	local canClaim, message, definition = QuestProgression.prepareClaim(profile, questId)
	if not canClaim or not definition then
		return false, message
	end

	if definition.rewardCash > 0 then
		ProfileManager.AddCash(player, definition.rewardCash)
	end
	if definition.rewardEmerald > 0 then
		ProfileManager.AddEmerald(player, definition.rewardEmerald)
	end
	if definition.rewardExperience > 0 then
		ProfileManager.AddExperience(player, definition.rewardExperience)
	end

	addQuestProgress(player, "QuestClaim", 1)
	ProfileManager.SyncProfileState(player)
	return true, message
end

function ProfileManager.ClaimDailyReward(player: Player)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return false, "Profile unavailable."
	end

	local now = os.time()
	local lastClaim = profile.Data.LastDailyReward or 0
	local secondsRemaining = (lastClaim + DAILY_COOLDOWN) - now
	if secondsRemaining > 0 then
		return false, "Come back tomorrow."
	end

	local reward = 3500 + ((profile.Data.Level or 1) * 175) + ((profile.Data.Rebirths or 0) * 500)
	profile.Data.LastDailyReward = now
	ProfileManager.AddCash(player, reward)
	ProfileManager.AddExperience(player, 90)
	addQuestProgress(player, "DailyClaim", 1)
	ProfileManager.SyncProfileState(player)
	return true, `Claimed ${reward} cash.`
end

function ProfileManager.TrackQuestMetric(player: Player, metric: string, amount: number?)
	addQuestProgress(player, metric, math.max(1, math.floor(amount or 1)))
end

function ProfileManager.BindQuestTracking(player: Player)
	local oldJanitor = ProfileManager.QuestTrackingJanitors[player]
	if oldJanitor then
		oldJanitor:Destroy()
	end

	local janitor = Janitor.new()
	local characterJanitor = Janitor.new()
	ProfileManager.QuestTrackingJanitors[player] = janitor
	janitor:Add(characterJanitor, "Destroy", "Character")

	local function bindCharacter(character: Model)
		characterJanitor:Cleanup()

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			humanoid = character:WaitForChild("Humanoid", 8) :: Humanoid?
		end
		if not humanoid then
			return
		end

		local lastJumpAt = 0
		characterJanitor:Add(
			humanoid.Jumping:Connect(function(active: boolean)
				if not active then
					return
				end

				local now = os.clock()
				if now - lastJumpAt < 0.35 then
					return
				end
				lastJumpAt = now
				addQuestProgress(player, "Jump", 1)
			end),
			"Disconnect",
			"Jumping"
		)
	end

	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	janitor:Add(player.CharacterAdded:Connect(bindCharacter), "Disconnect", "CharacterAdded")
end

do
	NetworkGuard.Query(Packets.queries.ProfileAction, "ProfileAction", {
		Rate = 8,
		Burst = 12,
		Validate = function(request)
			return type(request) == "table"
				and (request.action == "GetState" or request.action == "ClaimDaily" or request.action == "ClaimQuest")
				and (request.payload == nil or (type(request.payload) == "string" and #request.payload <= 64))
		end,
	}, function(request, player: Player?)
		if not player then
			return { success = false, message = "Player unavailable." }
		end

		if request.action == "GetState" then
			local state = buildProfileState(player)
			local payload = state and encodeProfileState(state)
			if not payload then
				return { success = false, message = "Profile unavailable." }
			end
			return { success = true, message = "", payload = payload }
		end

		if request.action == "ClaimDaily" then
			local success, message = ProfileManager.ClaimDailyReward(player)
			return { success = success == true, message = tostring(message) }
		elseif request.action == "ClaimQuest" and typeof(request.payload) == "string" then
			local success, message = ProfileManager.ClaimQuest(player, request.payload)
			return { success = success == true, message = tostring(message) }
		end

		warn(("[ProfileManager] %s sent unknown or malformed action: %s"):format(player.Name, tostring(request.action)))
		return { success = false, message = "Unknown profile action." }
	end)
end
function ProfileManager.HasCompletedOnboarding(player: Player): boolean
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return false
	end

	return profile.Data.Onboarding == true
end

function ProfileManager.OnboardingSuccess(player: Player): boolean
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return false
	end

	profile.Data.Onboarding = true
	ProfileManager.SyncProfileState(player)
	return true
end

return ProfileManager
