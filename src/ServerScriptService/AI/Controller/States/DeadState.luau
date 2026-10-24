--!strict

local Types = require(script.Parent.Parent.Core.Types)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike

local DeadState = {
	Name = "Dead",
}

function DeadState.Enter(context: AIContext)
	context.ObservationTarget = nil
end

function DeadState.Update(_context: AIContext, _machine: StateMachineLike) end

return DeadState
