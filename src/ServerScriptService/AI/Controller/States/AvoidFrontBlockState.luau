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
	Movement.ClearAvoidance(context)

	if context.AvoidMode == "Flee" then
		context.Humanoid.AutoRotate = true
		context.Humanoid.WalkSpeed = context.Config.FleeRunSpeed
		context.AvoidUntil = math.max(context.AvoidUntil, now + context.Config.FleeDuration)
		Movement.FleeFromTarget(context, blocker)
	elseif context.AvoidMode == "Backpedal" then
		context.Humanoid.WalkSpeed = math.max(9, context.Config.DefaultWalkSpeed * 1.05)
		context.AvoidUntil = math.max(context.AvoidUntil, now + context.Config.AvoidManeuverDuration)
		Movement.ManeuverAwayFromBlocker(context, blocker)
	else
		context.Humanoid.AutoRotate = true
		context.Humanoid.WalkSpeed = math.max(9, context.Config.DefaultWalkSpeed * 0.95)
		context.AvoidUntil = math.max(context.AvoidUntil, now + context.Config.AvoidManeuverDuration)
		Movement.ManeuverAwayFromBlocker(context, blocker)
	end
end

function AvoidFrontBlockState.Update(context: AIContext, machine: StateMachineLike)
	local now = os.clock()
	local blocker = context.AvoidTarget
	if blocker and blocker.Parent and now < context.AvoidUntil then
		if context.AvoidMode == "Flee" then
			context.Humanoid.AutoRotate = true
			context.Humanoid.WalkSpeed = context.Config.FleeRunSpeed
			Movement.FleeFromTarget(context, blocker)
		else
			context.Humanoid.AutoRotate = true
			context.Humanoid.WalkSpeed = math.max(9, context.Config.DefaultWalkSpeed)
			Movement.ManeuverAwayFromBlocker(context, blocker)
		end

		return
	end

	Movement.ClearAvoidance(context)
	context.AvoidTarget = nil
	context.AvoidLookTarget = nil
	context.AvoidPauseUntil = 0
	context.AvoidMode = "Sidestep"
	context.Humanoid.AutoRotate = true
	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
	machine:SetState("Patrol")
end

function AvoidFrontBlockState.Exit(context: AIContext)
	Movement.ClearAvoidance(context)
	context.AvoidMode = "Sidestep"
	context.Humanoid.AutoRotate = true
	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
end

return AvoidFrontBlockState
