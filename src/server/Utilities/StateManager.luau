--!strict

-- StateManager | Sacredbow | 2026.29.3
-- Usable across multiple systems

export type StateValue = boolean | number | string

export type StateManager = {
	Player: Player,
	States: {[string]: StateValue},
	SetState: (self: StateManager, state: string, value: StateValue?) -> (),
	GetState: (self: StateManager, state: string) -> StateValue?,
	HasState: (self: StateManager, state: string) -> boolean,
	RemoveState: (self: StateManager, state: string) -> (),
	Cleanup: (self: StateManager) -> (),
}

--- Schema of all valid states. Adding a new state requires it to be registered here first.
--- This prevents silent bugs from typos e.g "Electrifed" instead of "Electrified"
local VALID_STATES = {
	X2 = true,
	Electrified = true,
	ForceFieldEnabled = true,
	FriendBoost = true,
	RocketActivated = true,
	ArmourEquipped = true,
	Power = true,
}

local StateManager = {}
StateManager.__index = StateManager

--- Creates a new StateManager instance for a given player.
--- Should be created in PlayerService when the player joins.
--- @param player Player -- the player this StateManager belongs to
--- @return StateManager
function StateManager.new(player: Player): StateManager
	local self = {
		Player = player,
		States = {} :: {[string]: StateValue}
	}
	return setmetatable(self, StateManager) :: any
end

--- Sets a state to a given value, defaults to true if no value is provided.
--- Useful for boolean states: SetState("Electrified") is cleaner than SetState("Electrified", true)
--- @param state string -- must be a key in VALID_STATES
--- @param value StateValue? -- the value to set, defaults to true
function StateManager.SetState(self: StateManager, state: string, value: StateValue?)
	assert(typeof(state) == "string", `Expected string, got {typeof(state)}`)
	assert(VALID_STATES[state], `Unknown state: "{state}" — did you forget to register it in VALID_STATES?`)
	self.States[state] = if value ~= nil then value else true
end

--- Returns the raw value of a state, or nil if it hasn't been set.
--- Use HasState instead if you only need to check if a state is active.
--- @param state string -- must be a key in VALID_STATES
--- @return StateValue? -- the current value, or nil if not set
function StateManager.GetState(self: StateManager, state: string): StateValue?
	assert(typeof(state) == "string", `Expected string, got {typeof(state)}`)
	assert(VALID_STATES[state], `Unknown state: "{state}" — did you forget to register it in VALID_STATES?`)
	return self.States[state]
end

--- Returns true if a state is active (set and not false).
--- Prefer this over GetState for boolean checks — intent is clearer at the callsite.
--- @param state string -- must be a key in VALID_STATES
--- @return boolean -- true if the state is set and not false
function StateManager.HasState(self: StateManager, state: string): boolean
	assert(typeof(state) == "string", `Expected string, got {typeof(state)}`)
	assert(VALID_STATES[state], `Unknown state: "{state}" — did you forget to register it in VALID_STATES?`)
	local value = self.States[state]
	return value ~= nil and value ~= false
end

--- Removes a state entirely, equivalent to setting it to nil.
--- After this, HasState will return false and GetState will return nil.
--- @param state string -- must be a key in VALID_STATES
function StateManager.RemoveState(self: StateManager, state: string)
	assert(typeof(state) == "string", `Expected string, got {typeof(state)}`)
	assert(VALID_STATES[state], `Unknown state: "{state}" — did you forget to register it in VALID_STATES?`)
	self.States[state] = nil
end

--- Wipes all states for this player. Should be called in PlayerService:CleanupPlayer()
--- when the player leaves to avoid memory leaks.
function StateManager.Cleanup(self: StateManager)
	table.clear(self.States)
end

return StateManager