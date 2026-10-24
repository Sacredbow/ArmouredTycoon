--!strict

local Movement = require(script.Parent.Parent.Services.Movement)
local Dialogue = require(script.Parent.Parent.Services.Dialogue)
local Types = require(script.Parent.Parent.Core.Types)
local WorldQuery = require(script.Parent.Parent.Services.WorldQuery)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike

local PatrolState = {
	Name = "Patrol",
}

function PatrolState.Enter(context: AIContext)
	context.ObservationTarget = nil
	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
end

function PatrolState.Update(context: AIContext, machine: StateMachineLike)
	local now = os.clock()
	if (context :: any).NextPatrolRetryAt and now < (context :: any).NextPatrolRetryAt then
		return
	end

	local targetPosition: Vector3?
	if context.GoalDirection == "ToGoal" then
		targetPosition = WorldQuery.GetGoalPosition(context)
	else
		targetPosition = context.StartPivot.Position
	end

	if not targetPosition then
		(context :: any).NextPatrolRetryAt = now + context.Config.PathRetryDelay
		return
	end

	local frontBlocker = WorldQuery.FindFrontBlockingPlayer(context)
	if frontBlocker then
		context.AvoidTarget = frontBlocker
		machine:SetState("AvoidFrontBlock")
		return
	end

	local observablePlayers = WorldQuery.FindObservablePlayers(context)
	if #observablePlayers > 0 and Dialogue.PrepareObservation(context, observablePlayers) then
		machine:SetState("ObservePlayer")
		return
	end

	local reachedTarget = Movement.FollowPathTo(context, targetPosition, machine)
	if machine:GetStateName() ~= "Patrol" then
		return
	end

	if reachedTarget == nil then
		return
	elseif reachedTarget then
		if context.GoalDirection == "ToGoal" then
			context.GoalDirection = "ToStart"
		else
			context.GoalDirection = "ToGoal"
		end
		machine:SetState("Idle")
	else
		(context :: any).NextPatrolRetryAt = now + context.Config.PathRetryDelay
	end
end

return PatrolState
