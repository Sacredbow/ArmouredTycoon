--!strict
--[[
	@class NukeStore

	@desc
	Manages the active nuclear cinematic session and its packet listener.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)

--// Types

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
	mashOpen: boolean,
}

--// Module

local NukeStore = {}
NukeStore.__index = NukeStore

function NukeStore.new(): NukeStore
	local self = setmetatable({}, NukeStore) :: NukeStore
	self.NukeCinematic = nil
	self.Changed = Signal.new()
	self.Destroyed = false
	self.Started = false

	return self
end

function NukeStore:Start(Packets: any)
	if self.Started or not Packets then
		return
	end

	self.NukeConnection = Packets.packets.NukeCinematic.listen(function(payload)
		self:HandleNukeCinematic(payload)
	end)
	self.Started = true
end

--// Nuke Cinematic

function NukeStore:HandleNukeCinematic(Payload: any)
	if type(Payload) ~= "table" then
		return
	end

	local sessionId = Payload.sessionId
	if type(sessionId) ~= "string" or sessionId == "" then
		return
	end

	local current = self.NukeCinematic
	if Payload.action == "End" then
		if current and current.sessionId == sessionId then
			self.NukeCinematic = nil
			self.Changed:Fire()
		end
		return
	end

	-- One cinematic owns the camera/UI until its matching End arrives.
	if current and current.sessionId ~= sessionId then
		return
	end
	if not current and Payload.action ~= "Warning" and Payload.action ~= "Focus" then
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
		mashOpen = false,
	}

	Current.active = true
	Current.action = tostring(Payload.action or Current.action)
	Current.sessionId = sessionId
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
	if Payload.action == "MashStart" and (Current.role == "launcher" or Current.role == "defender") then
		Current.mashOpen = true
	elseif Payload.action == "Result" or Payload.action == "Impact" then
		Current.mashOpen = false
	end

	self.NukeCinematic = Current
	self.Changed:Fire()
end

--// Snapshots

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

	if self.NukeConnection then
		self.NukeConnection()
		self.NukeConnection = nil
	end

	local Changed = self.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type NukeStore = typeof(setmetatable({} :: {
	NukeCinematic: NukeCinematic?,
	Changed: any,
	Destroyed: boolean,
	Started: boolean,
	NukeConnection: any?,

	Start: (self: NukeStore, Packets: any) -> (),
	HandleNukeCinematic: (self: NukeStore, Payload: any) -> (),
	GetNukeSnapshot: (self: NukeStore) -> NukeCinematic?,
	Destroy: (self: NukeStore) -> (),
}, NukeStore))

return NukeStore

