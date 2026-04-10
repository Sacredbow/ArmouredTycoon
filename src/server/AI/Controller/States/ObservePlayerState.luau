--!strict

local Movement = require(script.Parent.Parent.Services.Movement)
local Dialogue = require(script.Parent.Parent.Services.Dialogue)
local Speech = require(script.Parent.Parent.Services.Speech)
local Types = require(script.Parent.Parent.Core.Types)
local WorldQuery = require(script.Parent.Parent.Services.WorldQuery)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike


local ObservePlayerState = {
	Name = "ObservePlayer",
}

local R6_WAVE_ANIMATION_ID = "rbxassetid://128777973"

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
		debugLog(context, `wave animation failed: {tostring(result)}`)
		animation:Destroy()
		return
	end

	debugLog(context, `wave animation started, track length {result}`)
end

function ObservePlayerState.Enter(context: AIContext)
	if context.ObservationHoldDuration > 0 then
		context.Humanoid.WalkSpeed = 0
		Movement.Stop(context)
	end
	debugLog(context, "entered observe state")

	if context.ObservationLine then
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
	if context.ObservationHoldDuration > 0 then
		local elapsed = 0
		while elapsed < context.ObservationHoldDuration do
			if machine:GetStateName() ~= "ObservePlayer" then
				return
			end

			if not observationTarget.Parent then
				break
			end

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
				context.AvoidMode = "Backpedal"
				context.AvoidPauseUntil = 0
				context.AvoidUntil = 0
				machine:SetState("AvoidFrontBlock")
				return
			end

			local currentLookPosition = observationTarget.Position
			local secondaryTarget = context.ObservationSecondaryTarget
			if secondaryTarget and secondaryTarget.Parent then
				currentLookPosition = (observationTarget.Position + secondaryTarget.Position) * 0.5
			end

			Movement.FaceTowardPositionStep(context, currentLookPosition, 0.35)
			elapsed += context.Config.LookStep
			task.wait(context.Config.LookStep)
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
	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
end

return ObservePlayerState
