--!strict

local Types = require(script.Parent.Types)

local Action = {}

type Action = Types.Action
type WorldState = Types.WorldState

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
