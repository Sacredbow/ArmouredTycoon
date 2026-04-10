--!strict

local Movement = require(script.Parent.Parent.Services.Movement)
local Types = require(script.Parent.Parent.Core.Types)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike


local IdleState = {
	Name = "Idle",
}

function IdleState.Enter(context: AIContext)
	Movement.Stop(context)
	context.Humanoid.WalkSpeed = 0
	context.IdleUntil = os.clock() + math.random() * (context.Config.IdleMaxDuration - context.Config.IdleMinDuration) + context.Config.IdleMinDuration
end

function IdleState.Update(context: AIContext, machine: StateMachineLike)
	if os.clock() < context.IdleUntil then
		return
	end

	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
	machine:SetState("Patrol")
end

function IdleState.Exit(context: AIContext)
	context.Humanoid.WalkSpeed = context.Config.DefaultWalkSpeed
end

return IdleState
