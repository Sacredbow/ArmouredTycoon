--!strict
--[[
	@class ProfileStore

	@desc
	Manages player profile state: level, XP, quests, daily rewards.
	Uses Replica for state syncing from the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Packages.signal)
local Janitor = require(ReplicatedStorage.Packages.janitor)
local QuestOptions = require(ReplicatedStorage.Progression.QuestOptions)

--// Types

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

--// Constants

const DEFAULT_PROFILE: ProfileState = {
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

--// Internal Helpers

local function CopyProfile(Profile: ProfileState): ProfileState
	local Quests = {}
	for QuestId, Quest in pairs(Profile.quests) do
		Quests[QuestId] = table.clone(Quest)
	end

	return {
		hydrated = Profile.hydrated,
		level = Profile.level,
		experience = Profile.experience,
		requiredExperience = Profile.requiredExperience,
		onboarding = Profile.onboarding,
		dailyReadyAt = Profile.dailyReadyAt,
		dailySecondsRemaining = Profile.dailySecondsRemaining,
		dailyQuestSecondsRemaining = Profile.dailyQuestSecondsRemaining,
		weeklyQuestSecondsRemaining = Profile.weeklyQuestSecondsRemaining,
		quests = Quests,
	}
end

--// Module

local ProfileStore = {}
ProfileStore.__index = ProfileStore

function ProfileStore.new(): ProfileStore
	local self = setmetatable({}, ProfileStore) :: ProfileStore

	self.Profile = CopyProfile(DEFAULT_PROFILE)
	self.Changed = Signal.new()
	self.Janitor = Janitor.new()
	self.ProfileReplicaJanitor = Janitor.new()
	self.Destroyed = false
	self.ReplicaRequested = false

	return self
end

function ProfileStore:Start(Packets: any)
	if self.Started then
		return
	end

	self.Started = true
	self.Janitor:Add(self.ProfileReplicaJanitor, "Destroy", "ProfileReplica")
	self:StartProfileReplica(Packets)
end

function ProfileStore:StartProfileReplica(Packets: any)
	if RunService:IsStudio() and not RunService:IsRunning() then
		return
	end

	local ReplicaModule = self:GetReplica()
	if not ReplicaModule then
		return
	end

	ReplicaModule.OnNew("ProfileState", function(Replica)
		if not self.Started then
			return
		end

		self.ProfileReplicaJanitor:Cleanup()
		self:SetProfileState(Replica.Data)
		self.ProfileReplicaJanitor:Add(Replica:OnChange(function()
			self:SetProfileState(Replica.Data)
		end), "Disconnect", "ProfileStateChanged")
	end)

	if not self.ReplicaRequested then
		self.ReplicaRequested = true
		ReplicaModule.RequestData()
	end
end

function ProfileStore:GetReplica()
	if RunService:IsStudio() and not RunService:IsRunning() then
		return nil
	end

	if not self.CachedReplica then
		local Ok, Result = pcall(function()
			return require(ReplicatedStorage.Packages.replica)
		end)
		if not Ok then
			return nil
		end
		self.CachedReplica = Result
	end

	return self.CachedReplica
end

function ProfileStore:SetProfileState(State: any)
	if typeof(State) ~= "table" then
		return
	end

	self.Profile = {
		hydrated = true,
		level = tonumber(State.level) or self.Profile.level,
		experience = tonumber(State.experience) or self.Profile.experience,
		requiredExperience = tonumber(State.requiredExperience) or self.Profile.requiredExperience,
		onboarding = State.onboarding == true,
		dailyReadyAt = tonumber(State.dailyReadyAt) or 0,
		dailySecondsRemaining = tonumber(State.dailySecondsRemaining) or self.Profile.dailySecondsRemaining,
		dailyQuestSecondsRemaining = tonumber(State.dailyQuestSecondsRemaining) or self.Profile.dailyQuestSecondsRemaining,
		weeklyQuestSecondsRemaining = tonumber(State.weeklyQuestSecondsRemaining) or self.Profile.weeklyQuestSecondsRemaining,
		quests = State.quests or self.Profile.quests,
	}

	self.Changed:Fire()
end

function ProfileStore:GetSnapshot(): ProfileState
	return CopyProfile(self.Profile)
end

function ProfileStore:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Started = false
	self.Janitor:Destroy()

	local Changed = self.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type ProfileStore = typeof(setmetatable({} :: {
	Profile: ProfileState,
	Changed: any,
	Janitor: any,
	ProfileReplicaJanitor: any,
	Destroyed: boolean,
	Started: boolean,
	ReplicaRequested: boolean,
	CachedReplica: any,

	Start: (self: ProfileStore, Packets: any) -> (),
	StartProfileReplica: (self: ProfileStore, Packets: any) -> (),
	GetReplica: (self: ProfileStore) -> any,
	SetProfileState: (self: ProfileStore, State: any) -> (),
	GetSnapshot: (self: ProfileStore) -> ProfileState,
	Destroy: (self: ProfileStore) -> (),
}, ProfileStore))

return ProfileStore

