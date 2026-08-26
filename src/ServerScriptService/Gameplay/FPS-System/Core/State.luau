--!strict
--[[
	@class FPSState

	@desc
	Shared mutable state for the server-side FPS combat engine.
	Consumed by all handler modules and initialized once by init.server.luau.
]]

local State = {
	-- Generated once per server run; used to authenticate combat requests.
	AuthToken = "",

	-- ECS entity id for each player's active weapon rig / stance entity.
	WeaponRigEntities = {} :: { [Player]: number },

	-- CharacterAdded connections for each player.
	CharacterConnections = {} :: { [Player]: RBXScriptConnection },

	-- Resolved ACS GameRules.Config module (loaded by init.server.luau).
	GameRules = nil :: any?,
}

return State
