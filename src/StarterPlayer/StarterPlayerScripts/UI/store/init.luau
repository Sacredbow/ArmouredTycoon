--!strict
--[[
	@class Store

	@desc
	Central re-export hub for all sub-store modules.
	Consumers should import from this module rather than individual stores.
]]

local GameStore = require(script.GameStore)
local useGameStore = require(script.useGameStore)

return {
	GameStore = GameStore,
	useGameStore = useGameStore,
}

