--!strict

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const ConversationOptions = require(script.Parent.ConversationOptions)
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const Observers = require(ReplicatedStorage.Packages.Observers)
const NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)
const Types = require(script.Parent.Parent.Core.Types)
const WorldQuery = require(script.Parent.WorldQuery)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike
type Option = ConversationOptions.Option

const MaxPlayerTurns = 7
const MaxConversationDistance = 24
const PlayerConversationCooldown = 5
const IdleTalkBlockDuration = 25
const IdleMoveThreshold = 1.4

const ConversationService = {}

const ActiveSessionsByPlayer: { [Player]: any } = {}
const ActiveSessionsByNpc: { [Model]: any } = {}
const ConversationCooldownByPlayer: { [Player]: number } = {}
const PlayerMovementByPlayer: { [Player]: { position: Vector3?, lastMovedAt: number } } = {}
local RemoteConnected = false
local MovementTrackerStarted = false

local function MakeNpcYield(context: AIContext, targetRoot: BasePart)
	local contextAny: any = context
	context.AvoidTarget = targetRoot
	context.AvoidLookTarget = targetRoot
	context.AvoidPauseUntil = 0
	context.AvoidMode = "Sidestep"
	context.AvoidUntil = os.clock() + context.Config.AvoidManeuverDuration
	context.IgnoreObservationUntil = context.AvoidUntil + 1
	context.ObservationShouldAvoidAfter = true
	context.ObservationAvoidMode = "Sidestep"
	context.ObservationHoldDuration = 0
	contextAny.ConversationActive = false
end

local function GetPlayerRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function UpdatePlayerMovement(player: Player, now: number)
	local root = GetPlayerRoot(player)
	if not root then
		PlayerMovementByPlayer[player] = {
			position = nil,
			lastMovedAt = now,
		}
		return
	end

	local state = PlayerMovementByPlayer[player]
	if not state then
		PlayerMovementByPlayer[player] = {
			position = root.Position,
			lastMovedAt = now,
		}
		return
	end

	if not state.position or (root.Position - state.position).Magnitude >= IdleMoveThreshold then
		state.position = root.Position
		state.lastMovedAt = now
	end
end

local function StartMovementTracker()
	if movementTrackerStarted then
		return
	end

	movementTrackerStarted = true
	Observers.observePlayer(function(player: Player)
		return function()
			PlayerMovementByPlayer[player] = nil
			ConversationCooldownByPlayer[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				UpdatePlayerMovement(player, now)
			end
			task.wait(1)
		end
	end)
end

local function PlayerHasBeenIdle(player: Player): boolean
	UpdatePlayerMovement(player, os.clock())
	local state = PlayerMovementByPlayer[player]
	return state ~= nil and os.clock() - state.lastMovedAt >= IdleTalkBlockDuration
end

local function GetPlayerDistance(player: Player, context: AIContext): number
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not playerRoot or not playerRoot:IsA("BasePart") then
		return math.huge
	end

	return (playerRoot.Position - WorldQuery.GetCurrentPosition(context)).Magnitude
end

local function SerializeOptions(options: { Option }): { any }
	local result = {}
	for index, option in options do
		result[index] = {
			id = option.id,
			text = option.text,
			tone = option.tone,
		}
	end

	return result
end

local function ClearSession(session, reason: string?)
	if ActiveSessionsByPlayer[session.player] == session then
		ActiveSessionsByPlayer[session.player] = nil
		ConversationCooldownByPlayer[session.player] = os.clock() + PlayerConversationCooldown
	end
	if ActiveSessionsByNpc[session.context.NPC] == session then
		ActiveSessionsByNpc[session.context.NPC] = nil
	end

	if session.player.Parent == Players then
		Packets.packets.NPCConversation.sendTo({
			action = "End",
			reason = reason or "Done",
		}, session.player)
	end
end

local function SendTurn(session)
	local options = ConversationOptions.GetOptions(session.context.Disposition, session.turnCount)
	session.options = options

	Packets.packets.NPCConversation.sendTo({
		action = "Open",
		conversationId = session.id,
		npcName = session.context.Name,
		npcLine = session.lastNpcLine,
		turnCount = session.turnCount,
		maxTurns = MaxPlayerTurns,
		options = SerializeOptions(options),
	}, session.player)
end

local function LeaveConversation(session, avoidMode: string?)
	local context: any = session.context
	local playerRoot = session.player.Character and session.player.Character:FindFirstChild("HumanoidRootPart")
	if playerRoot and playerRoot:IsA("BasePart") then
		context.AvoidTarget = playerRoot
		context.AvoidLookTarget = playerRoot
		context.AvoidPauseUntil = 0
		context.AvoidMode = avoidMode or "Sidestep"
		local avoidDuration = if avoidMode == "Flee" then context.Config.FleeDuration else context.Config.AvoidManeuverDuration
		context.AvoidUntil = os.clock() + avoidDuration
		context.IgnoreObservationUntil = context.AvoidUntil

		if context.StateMachine then
			context.StateMachine:SetState("AvoidFrontBlock")
		end
	end
end

local function FindOption(session, optionId: string): Option?
	for _, option in session.options or {} do
		if option.id == optionId then
			return option
		end
	end

	return nil
end

local function HandleChoice(player: Player, payload)
	local session = ActiveSessionsByPlayer[player]
	if not session or payload.conversationId ~= session.id then
		return
	end

	if GetPlayerDistance(player, session.context) > MaxConversationDistance then
		ClearSession(session, "TooFar")
		return
	end

	local option = FindOption(session, tostring(payload.optionId or ""))
	if not option then
		return
	end

	session.turnCount += 1
	local response = ConversationOptions.GetResponse(session.context.Disposition, option.tone, session.turnCount)
	session.lastNpcLine = response.line

	if option.tone == "Rude" then
		session.context.Disposition = "Abrasive"
		session.context.AbrasiveUntil = os.clock() + session.context.Config.AbrasiveRecoveryDuration
	end

	if response.endConversation or session.turnCount >= MaxPlayerTurns then
		ClearSession(session, "Done")
		if response.avoidMode then
			LeaveConversation(session, response.avoidMode)
		else
			session.context.IgnoreObservationUntil = os.clock() + session.context.Config.ObservationIgnoreDuration
		end
		return
	end

	SendTurn(session)
end

local function ConnectRemote()
	if remoteConnected then
		return
	end

	remoteConnected = true
	StartMovementTracker()
	NetworkGuard.Listen(Packets.packets.NPCConversationChoice, "NPCConversationChoice", {
	Rate = 8,
	Burst = 12,
	Validate = function(payload)
		return type(payload) == "table"
			and (payload.action == "Choose" or payload.action == "End")
			and type(payload.conversationId) == "string" and #payload.conversationId <= 64
			and (payload.action == "End" or (type(payload.optionId) == "string" and #payload.optionId <= 64))
	end,
}, function(payload, player: Player?)
		if not player then
			return
		end
		if type(payload) ~= "table" then
			return
		end

		if payload.action == "Choose" then
			HandleChoice(player, payload)
		elseif payload.action == "End" then
			local session = ActiveSessionsByPlayer[player]
			if session then
				ClearSession(session, "Done")
				session.context.IgnoreObservationUntil = os.clock() + session.context.Config.ObservationIgnoreDuration
			end
		end
	end)

	Observers.observePlayer(function(player: Player)
		return function()
			local session = ActiveSessionsByPlayer[player]
			if session then
				ClearSession(session, "Left")
			end
			ConversationCooldownByPlayer[player] = nil
			PlayerMovementByPlayer[player] = nil
		end
	end)
end

function ConversationService.TryStart(context: AIContext, targetRoot: BasePart): boolean
	ConnectRemote()

	local player = WorldQuery.GetPlayerFromRoot(targetRoot)
	if not player then
		return false
	end

	local existingPlayerSession = ActiveSessionsByPlayer[player]
	if existingPlayerSession then
		if existingPlayerSession.context.NPC == context.NPC then
			return true
		end

		MakeNpcYield(context, targetRoot)
		return false
	end

	local cooldownUntil = ConversationCooldownByPlayer[player] or 0
	if os.clock() < cooldownUntil then
		MakeNpcYield(context, targetRoot)
		return false
	end

	if PlayerHasBeenIdle(player) then
		MakeNpcYield(context, targetRoot)
		return false
	end

	local existingNpcSession = ActiveSessionsByNpc[context.NPC]
	if existingNpcSession then
		ClearSession(existingNpcSession, "Replaced")
	end

	local line = context.ObservationLine
	if not line or line == "" then
		line = "Need something?"
	end

	local session = {
		id = `{context.Name}:{player.UserId}:{math.floor(os.clock() * 1000)}`,
		player = player,
		context = context,
		turnCount = 0,
		lastNpcLine = line,
		options = {},
	}

	ActiveSessionsByPlayer[player] = session
	ActiveSessionsByNpc[context.NPC] = session

	SendTurn(session)

	task.delay(35, function()
		if ActiveSessionsByPlayer[player] == session then
			ClearSession(session, "TimedOut")
			context.IgnoreObservationUntil = os.clock() + context.Config.ObservationIgnoreDuration
		end
	end)

	return true
end

function ConversationService.EndForContext(context: AIContext)
	local session = ActiveSessionsByNpc[context.NPC]
	if session then
		ClearSession(session, "NpcLeft")
	end
end

function ConversationService.IsActive(context: AIContext): boolean
	return ActiveSessionsByNpc[context.NPC] ~= nil
end

StartMovementTracker()

return ConversationService
