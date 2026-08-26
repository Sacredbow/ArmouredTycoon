--!strict
--[[
	@class EnvironmentClockSystem

	@desc
	Advances EnvironmentClock entities — updates lighting via the
	clock service each tick at the configured time speed.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, Clock in World:query(Components.EnvironmentClock) do
		const Service = Clock.service
		if not Service then
			World:delete(Entity)
			continue
		end

		Clock.currentTime = (Clock.currentTime or 0) + (dt * Clock.timeSpeed)
		Service:_UpdateLighting(Clock.currentTime)
		World:set(Entity, Components.EnvironmentClock, Clock)
	end
end
