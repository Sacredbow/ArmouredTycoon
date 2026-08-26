--!strict
--[[
	@class StateManager

	@desc
	Generic per-player key-value state store.
	Callers are responsible for using consistent state name constants.

	| Sacredbow | 2026.29.3
]]

--// Types

export type StateValue = boolean | number | string

--// Module

local StateManager = {}
StateManager.__index = StateManager

--// Constructor

--- Creates a new StateManager instance for a given player.
--- Should be created in PlayerService when the player joins.
--- @param player Player -- the player this StateManager belongs to
--- @return StateManager
function StateManager.new(player: Player): StateManager
	local self = {
		Player = player,
		States = {} :: { [string]: StateValue },
	}

	return setmetatable(self, StateManager) :: any
end

--// Public API

--- Sets a state to a given value, defaults to true if no value is provided.
--- Useful for boolean states: SetState("Electrified") is cleaner than SetState("Electrified", true)
--- @param state string -- the state key to set
--- @param value StateValue? -- the value to set, defaults to true
function StateManager.SetState(self: StateManager, state: string, value: StateValue?)
	self.States[state] = if value ~= nil then value else true
end

--- Returns the raw value of a state, or nil if it hasn't been set.
--- Use HasState instead if you only need to check if a state is active.
--- @param state string -- the state key to read
--- @return StateValue? -- the current value, or nil if not set
function StateManager.GetState(self: StateManager, state: string): StateValue?
	return self.States[state]
end

--- Returns true if a state is active (set and not false).
--- Prefer this over GetState for boolean checks — intent is clearer at the callsite.
--- @param state string -- the state key to check
--- @return boolean -- true if the state is set and not false
function StateManager.HasState(self: StateManager, state: string): boolean
	local value = self.States[state]
	return value ~= nil and value ~= false
end

--- Removes a state entirely, equivalent to setting it to nil.
--- After this, HasState will return false and GetState will return nil.
--- @param state string -- the state key to remove
function StateManager.RemoveState(self: StateManager, state: string)
	self.States[state] = nil
end

--- Wipes all states for this player. Should be called in PlayerService:CleanupPlayer()
--- when the player leaves to avoid memory leaks.
function StateManager.Cleanup(self: StateManager)
	table.clear(self.States)
end

--// Type Export

export type StateManager = {
	Player: Player,
	States: { [string]: StateValue },
	SetState: (self: StateManager, state: string, value: StateValue?) -> (),
	GetState: (self: StateManager, state: string) -> StateValue?,
	HasState: (self: StateManager, state: string) -> boolean,
	RemoveState: (self: StateManager, state: string) -> (),
	Cleanup: (self: StateManager) -> (),
}

return StateManager

