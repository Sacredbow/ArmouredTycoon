--!strict
--[[
	@class StateMachine

	@desc
	Finite state machine for NPC controllers. State is held in a plain
	component-like table and advanced by the ECS NPC update system.
]]

const Types = require(script.Parent.Types)

type AIContext = Types.AIContext
type State = Types.State
type StateName = Types.StateName

local StateMachine = {}

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

function StateMachine.Create(Context: AIContext): StateMachineController
	local Controller: any = {
		Context = Context,
		States = {},
		CurrentState = nil,
		CurrentStateName = nil,
	}

	Controller.RegisterState = StateMachine.RegisterState
	Controller.GetStateName = StateMachine.GetStateName
	Controller.SetState = StateMachine.SetState
	Controller.Update = StateMachine.Update

	return Controller :: StateMachineController
end

function StateMachine.RegisterState(Controller: StateMachineController, StateValue: State)
	Controller.States[StateValue.Name] = StateValue
end

function StateMachine.GetStateName(Controller: StateMachineController): StateName?
	return Controller.CurrentStateName
end

function StateMachine.SetState(Controller: StateMachineController, StateNameValue: StateName)
	local NextState = Controller.States[StateNameValue]
	if not NextState then
		warn(`[AIStateMachine] Missing state "{StateNameValue}" for {Controller.Context.Name}`)
		return
	end

	if Controller.CurrentState == NextState then
		return
	end

	if Controller.CurrentState and Controller.CurrentState.Exit then
		Controller.CurrentState.Exit(Controller.Context, Controller)
	end

	Controller.CurrentState = NextState
	Controller.CurrentStateName = StateNameValue

	if NextState.Enter then
		NextState.Enter(Controller.Context, Controller)
	end
end

function StateMachine.Update(Controller: StateMachineController)
	if Controller.CurrentState then
		Controller.CurrentState.Update(Controller.Context, Controller)
	end
end

return StateMachine
