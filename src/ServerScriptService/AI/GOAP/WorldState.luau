--!strict

local Types = require(script.Parent.Types)

local WorldState = {}

type WorldState = Types.WorldState

function WorldState.matches(state: WorldState, query: WorldState): boolean
	for key, expected in query do
		if state[key] ~= expected then
			return false
		end
	end

	return true
end

function WorldState.apply(state: WorldState, effects: WorldState): WorldState
	local nextState = table.clone(state)
	for key, value in effects do
		nextState[key] = value
	end

	return nextState
end

function WorldState.distance(state: WorldState, goal: WorldState): number
	local misses = 0
	for key, expected in goal do
		if state[key] ~= expected then
			misses += 1
		end
	end

	return misses
end

return WorldState
