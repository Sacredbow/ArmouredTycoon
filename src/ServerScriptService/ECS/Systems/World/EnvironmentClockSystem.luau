--!strict
--[[
	@class EnvironmentClockSystem

	@desc
	Advances numeric EnvironmentClock state and delegates lighting through
	the environment module boundary.
]]

--// Modules

const ServerScriptService = game:GetService("ServerScriptService")
const EnvironmentService = require(ServerScriptService.Services.World.EnvironmentService)
--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, Clock in World:query(Components.EnvironmentClock) do
		Clock.currentTime = (Clock.currentTime or 0) + (dt * Clock.timeSpeed)
		EnvironmentService.UpdateLightingFromClock(Clock.currentTime)
		World:set(Entity, Components.EnvironmentClock, Clock)
	end
end
