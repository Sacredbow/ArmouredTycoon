--!strict
--[[
	@class Action

	@desc
	Factory for GOAP actions. Each action carries a cost, preconditions,
	effects, an optional scoring function, and a run callback.
]]

--// Modules

const Types = require(script.Parent.Types)

--// Types

type Action = Types.Action
type WorldState = Types.WorldState

--// Module

const Action = {}

--// Constructor

function Action.new(config: {
	name: string,
	cost: number?,
	preconditions: WorldState?,
	effects: WorldState?,
	score: ((Types.ActionContext) -> number)?,
	run: (Types.ActionContext) -> boolean,
}): Action
	return {
		name = config.name,
		cost = config.cost or 1,
		preconditions = config.preconditions or {},
		effects = config.effects or {},
		score = config.score,
		run = config.run,
	}
end

return Action
