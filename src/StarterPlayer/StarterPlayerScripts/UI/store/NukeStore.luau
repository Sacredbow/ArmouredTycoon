--!strict
--[[
	@class NukeStore

	@desc
	Manages nuke cinematic state and KOTH announcements.
	These are transient UI states that don't belong in other stores.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(ReplicatedStorage.Packages.signal)
local RuntimeSettings = require(ReplicatedStorage.Modules.SettingsManager.RuntimeSettings)
local SettingsConfig = require(ReplicatedStorage.Modules.SettingsManager.SettingsConfig)

--// Types

export type KOTHAnnouncement = {
	id: number,
	playerName: string,
	teamColor: Color3,
	minutes: number?,
	createdAt: number,
	duration: number,
}

export type NukeCinematic = {
	active: boolean,
	action: string,
	sessionId: string,
	role: string?,
	phase: string?,
	message: string,
	launcherName: string?,
	defenderName: string?,
	launcherUserId: string?,
	defenderUserId: string?,
	winnerName: string?,
	targetPosition: Vector3?,
	sourcePosition: Vector3?,
	distance: number?,
	deathRange: number?,
	timeLeft: number?,
	launcherScore: number,
	defenderScore: number,
}

--// Module

local NukeStore = {}
NukeStore.__index = NukeStore

function NukeStore.new(): NukeStore
	local self = setmetatable({}, NukeStore) :: NukeStore

	self.KOTHAnnouncement = nil
	self.NukeCinematic = nil
	self.Changed = Signal.new()
	self.NextKOTHAnnouncementId = 0
	self.Destroyed = false

	return self
end

function NukeStore:Start(Packets: any)
	if self.Started then
		return
	end

	self.Started = true

	if not Packets then
		return
	end

	self.KOTHConnection = Packets.packets.KOTHAnnouncement.listen(function(Data)
		self:PushKOTHAnnouncement(Data.playerName, Data.teamColor, Data.minutes)
	end)

	self.NukeConnection = Packets.packets.NukeCinematic.listen(function(Payload)
		self:HandleNukeCinematic(Payload)
	end)

	-- Observe settings for suppressing user announcements
	self.SettingsConnection = RuntimeSettings.Observe("User Announcements", function(Value)
		if Value ~= true and self.KOTHAnnouncement then
			self.KOTHAnnouncement = nil
			self.Changed:Fire()
		end
	end)
end

--// KOTH Announcements

function NukeStore:PushKOTHAnnouncement(PlayerName: string, TeamColor: Color3, Minutes: number?)
	if self:SuppressUserAnnouncements() then
		return
	end

	self.NextKOTHAnnouncementId += 1
	self.KOTHAnnouncement = {
		id = self.NextKOTHAnnouncementId,
		playerName = PlayerName,
		teamColor = TeamColor,
		minutes = Minutes,
		createdAt = os.clock(),
		duration = 4.5,
	}

	self.Changed:Fire()
end

function NukeStore:DismissKOTHAnnouncement(Id: number)
	if self.KOTHAnnouncement and self.KOTHAnnouncement.id == Id then
		self.KOTHAnnouncement = nil
		self.Changed:Fire()
	end
end

function NukeStore:SuppressUserAnnouncements(): boolean
	return RuntimeSettings.GetBoolean("User Announcements", SettingsConfig.default_settings["User Announcements"] == true) ~= true
end

--// Nuke Cinematic

function NukeStore:HandleNukeCinematic(Payload: any)
	if type(Payload) ~= "table" then
		return
	end

	if Payload.action == "End" then
		self.NukeCinematic = nil
		self.Changed:Fire()
		return
	end

	local Current = self.NukeCinematic or {
		active = true,
		action = tostring(Payload.action or ""),
		sessionId = tostring(Payload.sessionId or ""),
		role = Payload.role,
		phase = Payload.phase,
		message = tostring(Payload.message or "NUCLEAR INBOUND"),
		launcherName = Payload.launcherName,
		defenderName = Payload.defenderName,
		launcherUserId = Payload.launcherUserId,
		defenderUserId = Payload.defenderUserId,
		winnerName = Payload.winnerName,
		targetPosition = Payload.targetPosition,
		sourcePosition = Payload.sourcePosition,
		distance = Payload.distance,
		deathRange = Payload.deathRange,
		timeLeft = Payload.timeLeft,
		launcherScore = tonumber(Payload.launcherScore) or 0,
		defenderScore = tonumber(Payload.defenderScore) or 0,
	}

	Current.active = true
	Current.action = tostring(Payload.action or Current.action)
	Current.sessionId = tostring(Payload.sessionId or Current.sessionId)
	Current.role = Payload.role or Current.role
	Current.phase = Payload.phase or Current.phase
	Current.message = tostring(Payload.message or Current.message)
	Current.launcherName = Payload.launcherName or Current.launcherName
	Current.defenderName = Payload.defenderName or Current.defenderName
	Current.launcherUserId = Payload.launcherUserId or Current.launcherUserId
	Current.defenderUserId = Payload.defenderUserId or Current.defenderUserId
	Current.winnerName = Payload.winnerName or Current.winnerName
	Current.targetPosition = Payload.targetPosition or Current.targetPosition
	Current.sourcePosition = Payload.sourcePosition or Current.sourcePosition
	Current.distance = Payload.distance or Current.distance
	Current.deathRange = Payload.deathRange or Current.deathRange
	Current.timeLeft = Payload.timeLeft or Current.timeLeft
	Current.launcherScore = tonumber(Payload.launcherScore) or Current.launcherScore
	Current.defenderScore = tonumber(Payload.defenderScore) or Current.defenderScore

	self.NukeCinematic = Current
	self.Changed:Fire()
end

--// Snapshots

function NukeStore:GetKOTHSnapshot(): KOTHAnnouncement?
	return self.KOTHAnnouncement
end

function NukeStore:GetNukeSnapshot(): NukeCinematic?
	return self.NukeCinematic
end

--// Lifecycle

function NukeStore:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Started = false

	if self.KOTHConnection then
		self.KOTHConnection:Disconnect()
		self.KOTHConnection = nil
	end

	if self.NukeConnection then
		self.NukeConnection:Disconnect()
		self.NukeConnection = nil
	end

	if self.SettingsConnection then
		self.SettingsConnection:Disconnect()
		self.SettingsConnection = nil
	end

	local Changed = self.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type NukeStore = typeof(setmetatable({} :: {
	KOTHAnnouncement: KOTHAnnouncement?,
	NukeCinematic: NukeCinematic?,
	Changed: any,
	Destroyed: boolean,
	Started: boolean,
	NextKOTHAnnouncementId: number,
	KOTHConnection: any?,
	NukeConnection: any?,
	SettingsConnection: any?,

	Start: (self: NukeStore, Packets: any) -> (),
	PushKOTHAnnouncement: (self: NukeStore, PlayerName: string, TeamColor: Color3, Minutes: number?) -> (),
	DismissKOTHAnnouncement: (self: NukeStore, Id: number) -> (),
	SuppressUserAnnouncements: (self: NukeStore) -> boolean,
	HandleNukeCinematic: (self: NukeStore, Payload: any) -> (),
	GetKOTHSnapshot: (self: NukeStore) -> KOTHAnnouncement?,
	GetNukeSnapshot: (self: NukeStore) -> NukeCinematic?,
	Destroy: (self: NukeStore) -> (),
}, NukeStore))

return NukeStore

