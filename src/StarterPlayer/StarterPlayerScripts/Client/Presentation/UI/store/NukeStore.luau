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
NukeStore.NukeCinematic = nil
NukeStore.Changed = Signal.get("NukeStoreChanged")
NukeStore.Destroyed = false
NukeStore.Started = false
function NukeStore.Start(Packets: any)
	if NukeStore.Started or not Packets then
		return
	end

	NukeStore.NukeConnection = Packets.packets.NukeCinematic.listen(function(payload)
		NukeStore.HandleNukeCinematic(payload)
	end)
	local scorePacket = Packets.packets.NukeScore
	if scorePacket then
		NukeStore.ScoreConnection = scorePacket.listen(function(payload)
			NukeStore.HandleNukeScore(payload)
		end)
	end
	NukeStore.Started = true
end

--// Nuke Cinematic

function NukeStore.HandleNukeCinematic(Payload: any)
	if type(Payload) ~= "table" then
		return
	end

	local sessionId = Payload.sessionId
	if type(sessionId) ~= "string" or sessionId == "" then
		return
	end

	local current = NukeStore.NukeCinematic
	if Payload.action == "End" then
		if current and current.sessionId == sessionId then
			NukeStore.NukeCinematic = nil
			NukeStore.Changed:Fire()
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
	local Current = NukeStore.NukeCinematic
		or {
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

	NukeStore.NukeCinematic = Current
	NukeStore.Changed:Fire()
end

function NukeStore.HandleNukeScore(Payload: any)
	if type(Payload) ~= "table" or type(Payload.sessionId) ~= "string" then
		return
	end

	local current = NukeStore.NukeCinematic
	if not current or current.sessionId ~= Payload.sessionId then
		return
	end

	local launcherScore = tonumber(Payload.launcherScore)
	local defenderScore = tonumber(Payload.defenderScore)
	if launcherScore == nil or defenderScore == nil then
		return
	end

	current.launcherScore = math.clamp(math.floor(launcherScore), 0, 100)
	current.defenderScore = math.clamp(math.floor(defenderScore), 0, 100)
	NukeStore.Changed:Fire()
end

--// Snapshots

function NukeStore.GetNukeSnapshot(): NukeCinematic?
	return if NukeStore.NukeCinematic then table.clone(NukeStore.NukeCinematic) else nil
end

--// Lifecycle

function NukeStore.Destroy()
	if NukeStore.Destroyed then
		return
	end

	NukeStore.Destroyed = true
	NukeStore.Started = false

	if NukeStore.NukeConnection then
		NukeStore.NukeConnection()
		NukeStore.NukeConnection = nil
	end
	if NukeStore.ScoreConnection then
		NukeStore.ScoreConnection()
		NukeStore.ScoreConnection = nil
	end

	local Changed = NukeStore.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type NukeStore = typeof(NukeStore)

return NukeStore
