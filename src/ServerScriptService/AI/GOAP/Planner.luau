--!strict

local Types = require(script.Parent.Types)
local WorldState = require(script.Parent.WorldState)

local Planner = {}
Planner.__index = Planner

type Action = Types.Action
type ActionContext = Types.ActionContext
type Plan = Types.Plan
type WorldState = Types.WorldState

export type Planner = typeof(setmetatable({} :: {
	_actions: { Action },
	_maxDepth: number,
}, Planner))

local function actionCost(action: Action, context: ActionContext): number
	local score = if action.score then action.score(context) else 0
	return math.max(0.01, action.cost - score)
end

function Planner.new(maxDepth: number?): Planner
	return setmetatable({
		_actions = {},
		_maxDepth = maxDepth or 5,
	}, Planner)
end

function Planner:AddAction(action: Action)
	self._actions[#self._actions + 1] = action
end

function Planner:Plan(startState: WorldState, goal: WorldState, context: ActionContext): Plan?
	local bestPlan = nil :: Plan?
	local bestCost = math.huge

	local function search(state: WorldState, plan: Plan, cost: number, depth: number)
		if cost >= bestCost then
			return
		end

		if WorldState.matches(state, goal) then
			bestPlan = table.clone(plan)
			bestCost = cost
			return
		end

		if depth >= self._maxDepth then
			return
		end

		for _, action in self._actions do
			if WorldState.matches(state, action.preconditions) then
				plan[#plan + 1] = action
				search(
					WorldState.apply(state, action.effects),
					plan,
					cost + actionCost(action, context) + WorldState.distance(state, goal) * 0.1,
					depth + 1
				)
				plan[#plan] = nil
			end
		end
	end

	search(startState, {}, 0, 0)
	return bestPlan
end

return Planner
