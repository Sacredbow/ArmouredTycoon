--!strict

local Types = require(script.Parent.Types)
local Planner = require(script.Parent.Planner)

local Agent = {}
Agent.__index = Agent

type Action = Types.Action
type ActionContext = Types.ActionContext
type Plan = Types.Plan
type WorldState = Types.WorldState
type PlannerInstance = typeof(Planner.new())

export type Agent = typeof(setmetatable({} :: {
	_npc: Model,
	_blackboard: { [string]: any },
	_planner: PlannerInstance,
	_plan: Plan?,
	_goal: WorldState?,
}, Agent))

function Agent.new(npc: Model, maxDepth: number?): Agent
	return setmetatable({
		_npc = npc,
		_blackboard = {},
		_planner = Planner.new(maxDepth),
		_plan = nil,
		_goal = nil,
	}, Agent)
end

function Agent:AddAction(action: Action)
	self._planner:AddAction(action)
end

function Agent:SetGoal(goal: WorldState)
	self._goal = goal
	self._plan = nil
end

function Agent:GetBlackboard(): { [string]: any }
	return self._blackboard
end

function Agent:Think(world: WorldState): Plan?
	if not self._goal then
		return nil
	end

	local context: ActionContext = {
		npc = self._npc,
		blackboard = self._blackboard,
		world = world,
	}

	self._plan = self._planner:Plan(world, self._goal, context)
	return self._plan
end

function Agent:Step(world: WorldState): boolean
	local plan = self._plan or self:Think(world)
	if not plan or #plan == 0 then
		return false
	end

	local action = plan[1]
	local context: ActionContext = {
		npc = self._npc,
		blackboard = self._blackboard,
		world = world,
	}

	if action.run(context) then
		table.remove(plan, 1)
	end

	return true
end

return Agent
