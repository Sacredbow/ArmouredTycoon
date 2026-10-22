--!strict
--[[
	@class FPSState

	@desc
	Shared mutable state for the server-side FPS combat engine.
	Consumed by all handler modules and initialized once by init.server.luau.
]]

local State = {
	-- ECS entity id for each player's active weapon rig / stance entity.
	WeaponRigEntities = {} :: { [Player]: number },


	-- Resolved ACS GameRules.Config module (loaded by init.server.luau).
	GameRules = nil :: any?,
}

return State
