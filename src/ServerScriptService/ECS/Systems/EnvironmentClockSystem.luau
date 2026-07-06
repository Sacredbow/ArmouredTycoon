return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, clock in world:query(Components.EnvironmentClock) do
		local service = clock.service
		if not service then
			world:delete(entity)
			continue
		end

		clock.currentTime = (clock.currentTime or 0) + (dt * clock.timeSpeed)
		service:_UpdateLighting(clock.currentTime)
		world:set(entity, Components.EnvironmentClock, clock)
	end
end
