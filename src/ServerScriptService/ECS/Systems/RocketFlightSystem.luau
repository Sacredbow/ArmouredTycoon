return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, rocketFlight in world:query(Components.RocketFlight) do
		local rocket = rocketFlight.rocket
		if not rocket or not rocket.Rocket or not rocket.Rocket.Parent then
			world:delete(entity)
			continue
		end

		if rocket.isLaunched then
			rocket:UpdateSpeed(dt)
		else
			world:delete(entity)
		end
	end
end
