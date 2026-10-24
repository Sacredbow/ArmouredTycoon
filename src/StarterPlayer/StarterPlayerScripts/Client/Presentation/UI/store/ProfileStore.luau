--!strict
--[[
	@class ProfileStore

	@desc
	Owns the client profile snapshot and applies server-authoritative ByteNet
	updates. The store keeps the transport lifecycle separate from UI state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Signal = require(ReplicatedStorage.Packages.signal)
local Janitor = require(ReplicatedStorage.Packages.janitor)
local QuestOptions = require(ReplicatedStorage.Shared.Game.Progression.QuestOptions)

export type QuestProgress = {
	Progress: number,
	Completed: boolean,
	Claimed: boolean,
}

export type ProfileState = {
	hydrated: boolean,
	level: number,
	experience: number,
	requiredExperience: number,
	onboarding: boolean,
	dailyReadyAt: number,
	dailySecondsRemaining: number,
	dailyQuestSecondsRemaining: number,
	weeklyQuestSecondsRemaining: number,
	quests: { [string]: QuestProgress },
}

local DEFAULT_PROFILE: ProfileState = {
	hydrated = false,
	level = 1,
	experience = 0,
	requiredExperience = 120,
	onboarding = false,
	dailyReadyAt = 0,
	dailySecondsRemaining = 86400,
	dailyQuestSecondsRemaining = 86400,
	weeklyQuestSecondsRemaining = 604800,
	quests = QuestOptions.createProgressMap(),
}

local function copyQuestMap(quests: any): { [string]: QuestProgress }
	local copied = {}
	if type(quests) ~= "table" then
		return copied
	end

	for questId, quest in quests do
		if type(quest) == "table" then
			copied[questId] = table.clone(quest)
		end
	end
	return copied
end

local function copyProfile(profile: ProfileState): ProfileState
	return {
		hydrated = profile.hydrated,
		level = profile.level,
		experience = profile.experience,
		requiredExperience = profile.requiredExperience,
		onboarding = profile.onboarding,
		dailyReadyAt = profile.dailyReadyAt,
		dailySecondsRemaining = profile.dailySecondsRemaining,
		dailyQuestSecondsRemaining = profile.dailyQuestSecondsRemaining,
		weeklyQuestSecondsRemaining = profile.weeklyQuestSecondsRemaining,
		quests = copyQuestMap(profile.quests),
	}
end

local function profilesEqual(left: ProfileState, right: ProfileState): boolean
    if left.hydrated ~= right.hydrated
        or left.level ~= right.level
        or left.experience ~= right.experience
        or left.requiredExperience ~= right.requiredExperience
        or left.onboarding ~= right.onboarding
        or left.dailyReadyAt ~= right.dailyReadyAt
        or left.dailySecondsRemaining ~= right.dailySecondsRemaining
        or left.dailyQuestSecondsRemaining ~= right.dailyQuestSecondsRemaining
        or left.weeklyQuestSecondsRemaining ~= right.weeklyQuestSecondsRemaining then
        return false
    end

    local leftCount = 0
    for questId, quest in left.quests do
        leftCount += 1
        local other = right.quests[questId]
        if not other
            or quest.Progress ~= other.Progress
            or quest.Completed ~= other.Completed
            or quest.Claimed ~= other.Claimed then
            return false
        end
    end

    local rightCount = 0
    for _ in right.quests do
        rightCount += 1
    end
    return leftCount == rightCount
end

local ProfileStore = {}
ProfileStore.Profile = copyProfile(DEFAULT_PROFILE)
ProfileStore.Changed = Signal.get("ProfileStoreChanged")
ProfileStore.Janitor = Janitor.new()
ProfileStore.ProfileStateJanitor = Janitor.new()
ProfileStore.Destroyed = false
ProfileStore.Started = false
ProfileStore.StateListenerStarted = false
function ProfileStore.Start(Packets: any)
	if ProfileStore.Destroyed then
		return
	end
	ProfileStore.Started = true
	if not Packets or ProfileStore.StateListenerStarted then
		return
	end

	ProfileStore.StateListenerStarted = true
	ProfileStore.Janitor:Add(ProfileStore.ProfileStateJanitor, "Destroy", "ProfileState")
	ProfileStore.StartProfileState(Packets)
end

function ProfileStore.StartProfileState(Packets: any)
	local packet = Packets.packets and Packets.packets.ProfileState
	if not packet then
		return
	end

	local disconnect = packet.listen(function(data: any)
		if not ProfileStore.Started or type(data) ~= "table" or type(data.payload) ~= "string" then
			return
		end

		local ok, state = pcall(HttpService.JSONDecode, HttpService, data.payload)
		if ok then
			ProfileStore.SetProfileState(state)
		end
	end)
	ProfileStore.ProfileStateJanitor:Add(disconnect, true, "ProfileStateChanged")

	local query = Packets.queries and Packets.queries.ProfileAction
	if not query then
		return
	end

	task.spawn(function()
		local ok, result = pcall(function()
			return query.invoke({ action = "GetState" })
		end)
		if not ok or type(result) ~= "table" or result.success ~= true or type(result.payload) ~= "string" then
			return
		end

		local decoded, state = pcall(HttpService.JSONDecode, HttpService, result.payload)
		if decoded then
			ProfileStore.SetProfileState(state)
		end
	end)
end

function ProfileStore.SetProfileState(State: any)
	if type(State) ~= "table" then
		return
	end

    local nextProfile: ProfileState = {
        hydrated = true,
        level = tonumber(State.level) or ProfileStore.Profile.level,
        experience = tonumber(State.experience) or ProfileStore.Profile.experience,
        requiredExperience = tonumber(State.requiredExperience) or ProfileStore.Profile.requiredExperience,
        onboarding = State.onboarding == true,
        dailyReadyAt = tonumber(State.dailyReadyAt) or 0,
        dailySecondsRemaining = tonumber(State.dailySecondsRemaining) or ProfileStore.Profile.dailySecondsRemaining,
        dailyQuestSecondsRemaining = tonumber(State.dailyQuestSecondsRemaining) or ProfileStore.Profile.dailyQuestSecondsRemaining,
        weeklyQuestSecondsRemaining = tonumber(State.weeklyQuestSecondsRemaining) or ProfileStore.Profile.weeklyQuestSecondsRemaining,
        quests = copyQuestMap(State.quests),
    }

    if profilesEqual(ProfileStore.Profile, nextProfile) then
        return
    end

    ProfileStore.Profile = nextProfile
    ProfileStore.Changed:Fire()
end

function ProfileStore.GetSnapshot(): ProfileState
	return copyProfile(ProfileStore.Profile)
end

function ProfileStore.Destroy()
	if ProfileStore.Destroyed then
		return
	end

	ProfileStore.Destroyed = true
	ProfileStore.Started = false
	ProfileStore.Janitor:Destroy()

	local changed = ProfileStore.Changed :: any
	if changed.Destroy then
		changed:Destroy()
	end
end

export type ProfileStore = typeof(ProfileStore)

return ProfileStore
