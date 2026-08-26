--!strict
--[[
	@class Planner

	@desc
	GOAP planner — performs a depth-first search for a chain of actions
	that transforms the current world state into the goal state.
	Uses action cost + heuristic distance for pruning.
]]

--// Modules

const Types = require(script.Parent.Types)
const WorldStateModule = require(script.Parent.WorldState)

--// Types

type Action = Types.Action
type ActionContext = Types.ActionContext
type Plan = Types.Plan
type WorldState = Types.WorldState

--// Module

local Planner = {}
Planner.__index = Planner

export type Planner = typeof(setmetatable({} :: {
	_actions: { Action },
	_maxDepth: number,
}, Planner))

--// Internal Utilities

local function ActionCost(action: Action, context: ActionContext): number
	const Score = if action.score then action.score(context) else 0
	return math.max(0.01, action.cost - Score)
end

--// Constructor

function Planner.new(maxDepth: number?): Planner
	return setmetatable({
		_actions = {},
		_maxDepth = maxDepth or 5,
	}, Planner)
end

--// Public API

function Planner:AddAction(action: Action)
	self._actions[#self._actions + 1] = action
end

function Planner:Plan(StartState: WorldState, Goal: WorldState, Context: ActionContext): Plan?
	local BestPlan = nil :: Plan?
	local BestCost = math.huge

	local function Search(State: WorldState, Plan: Plan, Cost: number, Depth: number)
		if Cost >= BestCost then
			return
		end

		if WorldStateModule.matches(State, Goal) then
			BestPlan = table.clone(Plan)
			BestCost = Cost
			return
		end

		if Depth >= self._maxDepth then
			return
		end

		for _, Action in self._actions do
			if WorldStateModule.matches(State, Action.preconditions) then
				Plan[#Plan + 1] = Action
				Search(
					WorldStateModule.apply(State, Action.effects),
					Plan,
					Cost + ActionCost(Action, Context) + WorldStateModule.distance(State, Goal) * 0.1,
					Depth + 1
				)
				Plan[#Plan] = nil
			end
		end
	end

	Search(StartState, {}, 0, 0)
	return BestPlan
end

return Planner
