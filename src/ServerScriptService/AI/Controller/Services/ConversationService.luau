--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ConversationOptions = require(script.Parent.ConversationOptions)
local Packets = require(ReplicatedStorage.Network.Packets)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)
local Types = require(script.Parent.Parent.Core.Types)
local WorldQuery = require(script.Parent.WorldQuery)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike
type Option = ConversationOptions.Option

local MAX_PLAYER_TURNS = 7
local MAX_DISTANCE = 24
local PLAYER_CONVERSATION_COOLDOWN = 5
local IDLE_TALK_BLOCK_DURATION = 25
local IDLE_MOVE_THRESHOLD = 1.4

local ConversationService = {}

local activeByPlayer: { [Player]: any } = {}
local activeByNpc: { [Model]: any } = {}
local cooldownUntilByPlayer: { [Player]: number } = {}
local movementByPlayer: { [Player]: { position: Vector3?, lastMovedAt: number } } = {}
local remoteConnected = false
local movementTrackerStarted = false

local function makeNpcYield(context: AIContext, targetRoot: BasePart)
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

local function getPlayerRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function updatePlayerMovement(player: Player, now: number)
	local root = getPlayerRoot(player)
	if not root then
		movementByPlayer[player] = {
			position = nil,
			lastMovedAt = now,
		}
		return
	end

	local state = movementByPlayer[player]
	if not state then
		movementByPlayer[player] = {
			position = root.Position,
			lastMovedAt = now,
		}
		return
	end

	if not state.position or (root.Position - state.position).Magnitude >= IDLE_MOVE_THRESHOLD then
		state.position = root.Position
		state.lastMovedAt = now
	end
end

local function startMovementTracker()
	if movementTrackerStarted then
		return
	end

	movementTrackerStarted = true
	Players.PlayerRemoving:Connect(function(player)
		movementByPlayer[player] = nil
		cooldownUntilByPlayer[player] = nil
	end)

	task.spawn(function()
		while true do
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				updatePlayerMovement(player, now)
			end
			task.wait(1)
		end
	end)
end

local function playerHasBeenIdle(player: Player): boolean
	updatePlayerMovement(player, os.clock())
	local state = movementByPlayer[player]
	return state ~= nil and os.clock() - state.lastMovedAt >= IDLE_TALK_BLOCK_DURATION
end

local function getPlayerDistance(player: Player, context: AIContext): number
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not playerRoot or not playerRoot:IsA("BasePart") then
		return math.huge
	end

	return (playerRoot.Position - WorldQuery.GetCurrentPosition(context)).Magnitude
end

local function serializeOptions(options: { Option }): { any }
	local result = {}
	for index, option in ipairs(options) do
		result[index] = {
			id = option.id,
			text = option.text,
			tone = option.tone,
		}
	end

	return result
end

local function clearSession(session, reason: string?)
	if activeByPlayer[session.player] == session then
		activeByPlayer[session.player] = nil
		cooldownUntilByPlayer[session.player] = os.clock() + PLAYER_CONVERSATION_COOLDOWN
	end
	if activeByNpc[session.context.NPC] == session then
		activeByNpc[session.context.NPC] = nil
	end

	if session.player.Parent == Players then
		Packets.packets.NPCConversation.sendTo({
			action = "End",
			reason = reason or "Done",
		}, session.player)
	end
end

local function sendTurn(session)
	local options = ConversationOptions.GetOptions(session.context.Disposition, session.turnCount)
	session.options = options

	Packets.packets.NPCConversation.sendTo({
		action = "Open",
		conversationId = session.id,
		npcName = session.context.Name,
		npcLine = session.lastNpcLine,
		turnCount = session.turnCount,
		maxTurns = MAX_PLAYER_TURNS,
		options = serializeOptions(options),
	}, session.player)
end

local function leaveConversation(session, avoidMode: string?)
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

local function findOption(session, optionId: string): Option?
	for _, option in ipairs(session.options or {}) do
		if option.id == optionId then
			return option
		end
	end

	return nil
end

local function handleChoice(player: Player, payload)
	local session = activeByPlayer[player]
	if not session or payload.conversationId ~= session.id then
		return
	end

	if getPlayerDistance(player, session.context) > MAX_DISTANCE then
		clearSession(session, "TooFar")
		return
	end

	local option = findOption(session, tostring(payload.optionId or ""))
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

	if response.endConversation or session.turnCount >= MAX_PLAYER_TURNS then
		clearSession(session, "Done")
		if response.avoidMode then
			leaveConversation(session, response.avoidMode)
		else
			session.context.IgnoreObservationUntil = os.clock() + session.context.Config.ObservationIgnoreDuration
		end
		return
	end

	sendTurn(session)
end

local function connectRemote()
	if remoteConnected then
		return
	end

	remoteConnected = true
	startMovementTracker()
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
			handleChoice(player, payload)
		elseif payload.action == "End" then
			local session = activeByPlayer[player]
			if session then
				clearSession(session, "Done")
				session.context.IgnoreObservationUntil = os.clock() + session.context.Config.ObservationIgnoreDuration
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local session = activeByPlayer[player]
		if session then
			clearSession(session, "Left")
		end
		cooldownUntilByPlayer[player] = nil
		movementByPlayer[player] = nil
	end)
end

function ConversationService.TryStart(context: AIContext, targetRoot: BasePart): boolean
	connectRemote()

	local player = WorldQuery.GetPlayerFromRoot(targetRoot)
	if not player then
		return false
	end

	local existingPlayerSession = activeByPlayer[player]
	if existingPlayerSession then
		if existingPlayerSession.context.NPC == context.NPC then
			return true
		end

		makeNpcYield(context, targetRoot)
		return false
	end

	local cooldownUntil = cooldownUntilByPlayer[player] or 0
	if os.clock() < cooldownUntil then
		makeNpcYield(context, targetRoot)
		return false
	end

	if playerHasBeenIdle(player) then
		makeNpcYield(context, targetRoot)
		return false
	end

	local existingNpcSession = activeByNpc[context.NPC]
	if existingNpcSession then
		clearSession(existingNpcSession, "Replaced")
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

	activeByPlayer[player] = session
	activeByNpc[context.NPC] = session

	sendTurn(session)

	task.delay(35, function()
		if activeByPlayer[player] == session then
			clearSession(session, "TimedOut")
			context.IgnoreObservationUntil = os.clock() + context.Config.ObservationIgnoreDuration
		end
	end)

	return true
end

function ConversationService.EndForContext(context: AIContext)
	local session = activeByNpc[context.NPC]
	if session then
		clearSession(session, "NpcLeft")
	end
end

function ConversationService.IsActive(context: AIContext): boolean
	return activeByNpc[context.NPC] ~= nil
end

startMovementTracker()

return ConversationService
