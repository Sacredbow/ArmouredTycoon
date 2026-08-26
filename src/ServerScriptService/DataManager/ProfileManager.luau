local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")


local ProfileManager = {}
local Packets = require(ReplicatedStorage.Network.Packets)
local Janitor = require(ReplicatedStorage.Packages.janitor)
local Replica = require(ReplicatedStorage.Packages.replica)
local QuestOptions = require(ReplicatedStorage.Progression.QuestOptions)
local QuestProgression = require(ServerScriptService.Gameplay.Progression.QuestProgression)
local SoundManager = require(ServerScriptService.Utilities.SoundManager)

-- Store profiles from the Profile Store.

ProfileManager.Profiles = {}
ProfileManager.ProfileReplicas = {}
ProfileManager.ProfileReplicaJanitors = {}
ProfileManager.QuestTrackingJanitors = {}

local DAILY_COOLDOWN = QuestOptions.DailyCooldown
local ProfileStateToken = Replica.Token("ProfileState")
local PROFILE_STATE_KEYS = {
    "level",
    "experience",
    "requiredExperience",
    "onboarding",
    "dailyReadyAt",
    "dailySecondsRemaining",
    "dailyQuestSecondsRemaining",
    "weeklyQuestSecondsRemaining",
    "quests",
}

local function copyQuestState(quests: { [string]: any }): { [string]: any }
    local copied = {}
    for questId, quest in pairs(quests) do
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

local function subscribeProfileReplica(player: Player, replica, janitor)
	if Replica.ReadyPlayers[player] then
		replica:Subscribe(player)
		return
	end

	janitor:Add(Replica.NewReadyPlayer:Connect(function(readyPlayer: Player)
		if readyPlayer ~= player then
			return
		end

		janitor:Remove("ReadyConnection")
		if ProfileManager.ProfileReplicas[player] == replica and player.Parent == Players then
			replica:Subscribe(player)
		end
	end), "Disconnect", "ReadyConnection")
end

local function updateProfileReplica(player: Player, state: { [string]: any })
	local replica = ProfileManager.ProfileReplicas[player]
	if not replica then
		local janitor = Janitor.new()
		replica = Replica.new({
			Token = ProfileStateToken,
			Tags = {
				Player = player.Name,
			},
			Data = state,
		})
		ProfileManager.ProfileReplicas[player] = replica
		ProfileManager.ProfileReplicaJanitors[player] = janitor
		janitor:Add(replica, "Destroy", "Replica")
		subscribeProfileReplica(player, replica, janitor)
		return
	end

	for _, key in ipairs(PROFILE_STATE_KEYS) do
		replica:Set({ key }, state[key])
	end
end

function ProfileManager.SyncProfileState(player: Player)
	local state = buildProfileState(player)
	if state then
		updateProfileReplica(player, state)
	end
end

function ProfileManager.ReleaseProfileState(player: Player)
	local replicaJanitor = ProfileManager.ProfileReplicaJanitors[player]
	if replicaJanitor then
		replicaJanitor:Destroy()
		ProfileManager.ProfileReplicaJanitors[player] = nil
	end
	ProfileManager.ProfileReplicas[player] = nil

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
	if not profile then return end
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
function ProfileManager.AddEmerald(player : Player, amount : number)
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
function ProfileManager.AddKills(player : Player, amount : number)
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
function ProfileManager.AddRebirths(player : Player, amount : number)
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
		characterJanitor:Add(humanoid.Jumping:Connect(function(active: boolean)
			if not active then
				return
			end

			local now = os.clock()
			if now - lastJumpAt < 0.35 then
				return
			end
			lastJumpAt = now
			addQuestProgress(player, "Jump", 1)
		end), "Disconnect", "Jumping")
	end

	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	janitor:Add(player.CharacterAdded:Connect(bindCharacter), "Disconnect", "CharacterAdded")
end

do
	Packets.queries.ProfileAction.listen(function(request, player: Player?)
		if not player then
			return { success = false, message = "Player unavailable." }
		end

		if request.action == "ClaimDaily" then
			local success, message = ProfileManager.ClaimDailyReward(player)
			return { success = success == true, message = tostring(message) }
		elseif request.action == "ClaimQuest" and typeof(request.payload) == "string" then
			local success, message = ProfileManager.ClaimQuest(player, request.payload)
			return { success = success == true, message = tostring(message) }
		end

warn(`[ProfileManager] {player.Name} sent unknown or malformed action: {tostring(request.action)}`)
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




