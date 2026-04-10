--!strict

local Movement = require(script.Parent.Parent.Services.Movement)
local Types = require(script.Parent.Parent.Core.Types)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike


local AvoidFrontBlockState = {
	Name = "AvoidFrontBlock",
}

function AvoidFrontBlockState.Enter(context: AIContext, machine: StateMachineLike)
	local blocker = context.AvoidTarget
	if not blocker or not blocker.Parent then
		context.AvoidTarget = nil
		context.AvoidLookTarget = nil
		context.AvoidPauseUntil = 0
		context.AvoidMode = "Sidestep"
		machine:SetState("Patrol")
		return
	end

	local now = os.clock()
	if context.AvoidLookTarget and now < context.AvoidPauseUntil then
		context.Humanoid.AutoRotate = true
		context.Humanoid.WalkSpeed = 0
		return
	end

	context.Humanoid.WalkSpeed = math.max(8, context.Config.DefaultWalkSpeed * 0.85)
	if context.AvoidMode == "Backpedal" then
		Movement.BackAwayFromTarget(context, blocker)
	else
		context.Humanoid.AutoRotate = true
		local chosenDirection = Movement.StepAwayFromBlocker(context, blocker, context.AvoidDirection)
		context.AvoidDirection = chosenDirection
	end

	if context.AvoidUntil <= now then
		context.AvoidUntil = now + context.Config.AvoidDuration
	end
end

function AvoidFrontBlockState.Update(context: AIContext, machine: StateMachineLike)
	local now = os.clock()
	local lookTarget = context.AvoidLookTarget
	if lookTarget and lookTarget.Parent and now < context.AvoidPauseUntil then
		Movement.FaceTowardPositionStep(context, lookTarget.Position, 0.35)
		if context.AvoidMode == "Backpedal" then
			context.Humanoid.WalkSpeed = math.max(7, context.Config.DefaultWalkSpeed * 0.7)
			Movement.BackAwayFromTarget(context, lookTarget)
		end

		return
	end

	if context.AvoidLookTarget then
		context.AvoidLookTarget = nil
		context.AvoidPauseUntil = 0

		local blocker = context.AvoidTarget
		if blocker and blocker.Parent then
			context.Humanoid.WalkSpeed = math.max(8, context.Config.DefaultWalkSpeed * 0.85)
			if context.AvoidMode == "Backpedal" then
				Movement.BackAwayFromTarget(context, blocker)
			else
				context.Humanoid.AutoRotate = true
				context.AvoidDirection = Movement.StepAwayFromBlocker(context, blocker, context.AvoidDirection)
			end
			context.AvoidUntil = now + context.Config.AvoidDuration
			return
		end
	end

	if now < context.AvoidUntil then
		if context.AvoidMode == "Backpedal" then
			local blocker = context.AvoidTarget
			if blocker and blocker.Parent then
				context.Humanoid.WalkSpeed = math.max(7, context.Config.DefaultWalkSpeed * 0.7)
				Movement.BackAwayFromTarget(context, blocker)
			end
		end

		return
	end

	context.AvoidTarget = nil
	context.AvoidLookTarget = nil
	context.AvoidPauseUntil = 0
	context.AvoidMode = "Sidestep"
	context.Humanoid.AutoRotate = true
	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
	machine:SetState("Patrol")
end

function AvoidFrontBlockState.Exit(context: AIContext)
	context.AvoidMode = "Sidestep"
	context.Humanoid.AutoRotate = true
	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
end

return AvoidFrontBlockState
