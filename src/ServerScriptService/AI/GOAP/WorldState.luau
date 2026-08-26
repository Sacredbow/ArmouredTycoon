--!strict
--[[
	@class WorldState

	@desc
	GOAP world state utility functions: matching, applying effects, and
	heuristic distance calculation between states.
]]

--// Modules

const Types = require(script.Parent.Types)

--// Types

type WorldState = Types.WorldState

--// Module

const WorldState = {}

--// Public API

function WorldState.matches(State: WorldState, Query: WorldState): boolean
	for Key, Expected in Query do
		if State[Key] ~= Expected then
			return false
		end
	end

	return true
end

function WorldState.apply(State: WorldState, Effects: WorldState): WorldState
	const NextState = table.clone(State)
	for Key, Value in Effects do
		NextState[Key] = Value
	end

	return NextState
end

function WorldState.distance(State: WorldState, Goal: WorldState): number
	local Misses = 0
	for Key, Expected in Goal do
		if State[Key] ~= Expected then
			Misses += 1
		end
	end

	return Misses
end

return WorldState
