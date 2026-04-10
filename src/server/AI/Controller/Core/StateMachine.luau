--!strict

local Types = require(script.Parent.Types)

type AIContext = Types.AIContext
type State = Types.State
type StateName = Types.StateName

local StateMachine = {}
StateMachine.__index = StateMachine

export type StateMachineController = {
	Context: AIContext,
	States: { [string]: State },
	CurrentState: State?,
	CurrentStateName: StateName?,
	RegisterState: (self: StateMachineController, state: State) -> (),
	GetStateName: (self: StateMachineController) -> StateName?,
	SetState: (self: StateMachineController, stateName: StateName) -> (),
	Update: (self: StateMachineController) -> (),
}

function StateMachine.new(context: AIContext): StateMachineController
	local self : any = setmetatable({
		Context = context,
		States = {},
		CurrentState = nil,
		CurrentStateName = nil,
	}, StateMachine) 
	return self  :: StateMachineController
end

function StateMachine.RegisterState(self: StateMachineController, state: State)
	self.States[state.Name] = state
end

function StateMachine.GetStateName(self: StateMachineController): StateName?
	return self.CurrentStateName
end

function StateMachine.SetState(self: StateMachineController, stateName: StateName)
	local nextState = self.States[stateName]
	if not nextState then
		warn(`[AIStateMachine] Missing state "{stateName}" for {self.Context.Name}`)
		return
	end

	if self.CurrentState == nextState then
		return
	end

	if self.CurrentState and self.CurrentState.Exit then
		self.CurrentState.Exit(self.Context, self)
	end

	self.CurrentState = nextState
	self.CurrentStateName = stateName

	if nextState.Enter then
		nextState.Enter(self.Context, self)
	end
end

function StateMachine.Update(self: StateMachineController)
	if self.CurrentState then
		self.CurrentState.Update(self.Context, self)
	end
end

return StateMachine
