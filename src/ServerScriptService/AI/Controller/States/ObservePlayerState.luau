--!strict
--[[
	@class ObservePlayerState

	@desc
	NPC state where the NPC observes a nearby player — faces them,
	speaks an observation line, optionally waves, and may start a
	conversation or trigger an avoidance reaction if the player is armed.
]]

--// Services

const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const Movement = require(script.Parent.Parent.Services.Movement)
const ConversationService = require(script.Parent.Parent.Services.ConversationService)
const Dialogue = require(script.Parent.Parent.Services.Dialogue)
const Speech = require(script.Parent.Parent.Services.Speech)
const Types = require(script.Parent.Parent.Core.Types)
const WorldQuery = require(script.Parent.Parent.Services.WorldQuery)

--// Types

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike

--// Module

local ObservePlayerState = {
	Name = "ObservePlayer",
}

--// Constants

const R6_WAVE_ANIMATION_ID = "rbxassetid://128777973"

local function debugLog(context: AIContext, message: string)
	if not context.Config.DebugObservation then
		return
	end

	print(`[AI Observe] {context.Name}: {message}`)
end

local function tryPlayWave(context: AIContext)
	local animator = context.Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = context.Humanoid
	end

	local animationId = R6_WAVE_ANIMATION_ID

	debugLog(context, `attempting wave animation {animationId} on rig {context.Humanoid.RigType.Name}`)

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local success, result = pcall(function()
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		track:Play(0.1)
		track.Stopped:Once(function()
			track:Destroy()
			animation:Destroy()
		end)
		return track.Length
	end)

if not success then
		warn(`[AI.ObservePlayer] Wave animation failed for {context.Name}: {tostring(result)}`)
		animation:Destroy()
		return
	end

	debugLog(context, `wave animation started, track length {result}`)
end

function ObservePlayerState.Enter(context: AIContext)
	(context :: any).ObservationStartedAt = os.clock();
	(context :: any).ConversationActive = false
	if context.ObservationHoldDuration > 0 then
		context.Humanoid.WalkSpeed = 0
		Movement.Stop(context)
	end
	debugLog(context, "entered observe state")

	if context.ObservationTarget and not WorldQuery.IsPlayerArmed(context.ObservationTarget) then
		(context :: any).ConversationActive = ConversationService.TryStart(context, context.ObservationTarget)
	end

	if
		context.ObservationLine
		and not (context :: any).ConversationActive
		and not context.ObservationShouldAvoidAfter
	then
		Speech.Say(context, context.ObservationLine)
	end

	if context.ObservationShouldWave then
		tryPlayWave(context)
	end
end

function ObservePlayerState.Update(context: AIContext, machine: StateMachineLike)
	local observationTarget = context.ObservationTarget
	if not observationTarget or not observationTarget.Parent then
		debugLog(context, "observation target missing, returning to patrol")
		context.ObservationTarget = nil
		context.ObservationSecondaryTarget = nil
		context.ObservationLine = nil
		context.ObservationLookPosition = nil
		context.ObservationHoldDuration = context.Config.ObservationDuration
		context.ObservationShouldWave = false
		context.ObservationShouldAvoidAfter = false
		context.ObservationAvoidMode = "Sidestep"
		machine:SetState("Patrol")
		return
	end

	debugLog(context, `looking at target {observationTarget:GetFullName()}`)
	if (context :: any).ConversationActive then
		if not ConversationService.IsActive(context) then
			debugLog(context, "conversation finished, returning to patrol");
			(context :: any).ConversationActive = false
			context.ObservationTarget = nil
			context.ObservationSecondaryTarget = nil
			context.ObservationLine = nil
			context.ObservationLookPosition = nil
			context.ObservationHoldDuration = context.Config.ObservationDuration
			context.ObservationShouldWave = false
			context.ObservationShouldAvoidAfter = false
			context.ObservationAvoidMode = "Sidestep"
			machine:SetState("Patrol")
			return
		end

		local distance = (observationTarget.Position - WorldQuery.GetCurrentPosition(context)).Magnitude
		if distance > context.Config.ObservationRadius * 1.8 then
			ConversationService.EndForContext(context);
			(context :: any).ConversationActive = false
			context.IgnoreObservationUntil = os.clock() + context.Config.ObservationIgnoreDuration
			machine:SetState("Patrol")
			return
		end

		Movement.FaceTowardPositionStep(context, observationTarget.Position, 0.28)
		return
	end

	if context.ObservationHoldDuration > 0 then
		if WorldQuery.IsPlayerArmed(observationTarget) then
			debugLog(context, "target armed during observation, interrupting to backpedal")
			Speech.Say(context, Dialogue.GetArmedReactionLine(context))
			context.ObservationTarget = nil
			context.ObservationSecondaryTarget = nil
			context.ObservationLine = nil
			context.ObservationLookPosition = nil
			context.ObservationHoldDuration = context.Config.ObservationDuration
			context.ObservationShouldWave = false
			context.ObservationShouldAvoidAfter = false
			context.ObservationAvoidMode = "Sidestep"
			context.AvoidTarget = observationTarget
			context.AvoidLookTarget = observationTarget
			context.AvoidMode = "Flee"
			context.AvoidPauseUntil = 0
			context.AvoidUntil = os.clock() + context.Config.FleeDuration
			context.IgnoreObservationUntil = context.AvoidUntil
			machine:SetState("AvoidFrontBlock")
			return
		end

		local currentLookPosition = observationTarget.Position
		local secondaryTarget = context.ObservationSecondaryTarget
		if secondaryTarget and secondaryTarget.Parent then
			currentLookPosition = (observationTarget.Position + secondaryTarget.Position) * 0.5
		end

		Movement.FaceTowardPositionStep(context, currentLookPosition, 0.35)

		local startedAt = (context :: any).ObservationStartedAt or os.clock()
		if os.clock() - startedAt < context.ObservationHoldDuration then
			return
		end
	end

	local shouldAvoidAfter = context.ObservationShouldAvoidAfter
	local avoidMode = context.ObservationAvoidMode
	context.ObservationTarget = nil
	context.ObservationSecondaryTarget = nil
	context.ObservationLine = nil
	context.ObservationLookPosition = nil
	context.ObservationHoldDuration = context.Config.ObservationDuration
	context.ObservationShouldWave = false
	context.ObservationShouldAvoidAfter = false
	context.ObservationAvoidMode = "Sidestep"
	debugLog(context, "finished observing, returning to patrol")

	if shouldAvoidAfter then
		context.AvoidTarget = observationTarget
		context.AvoidLookTarget = observationTarget
		context.AvoidMode = avoidMode
		context.AvoidPauseUntil = 0
		context.AvoidUntil = 0
		machine:SetState("AvoidFrontBlock")
		return
	end

	machine:SetState("Patrol")
end

function ObservePlayerState.Exit(context: AIContext)
	if (context :: any).ConversationActive then
		ConversationService.EndForContext(context)
	end
	(context :: any).ConversationActive = nil
	(context :: any).ObservationStartedAt = nil
	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
end

return ObservePlayerState
