--!strict
--[[
	@class RocketFlightSystem

	@desc
	Updates rocket flight speed for launched RocketFlight entities.
	Cleans up if the rocket model or entity is destroyed.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, RocketFlight in World:query(Components.RocketFlight) do
		const Rocket = RocketFlight.rocket
		if not Rocket or not Rocket.Rocket or not Rocket.Rocket.Parent then
			World:delete(Entity)
			continue
		end

		if Rocket.isLaunched then
			Rocket:UpdateSpeed(dt)
		else
			World:delete(Entity)
		end
	end
end
