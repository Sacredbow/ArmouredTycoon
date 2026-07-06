--!strict

export type WorldState = { [string]: boolean | number | string }

export type ActionContext = {
	npc: Model,
	blackboard: { [string]: any },
	world: WorldState,
}

export type Action = {
	name: string,
	cost: number,
	preconditions: WorldState,
	effects: WorldState,
	score: ((ActionContext) -> number)?,
	run: (ActionContext) -> boolean,
}

export type Plan = { Action }

return {}
