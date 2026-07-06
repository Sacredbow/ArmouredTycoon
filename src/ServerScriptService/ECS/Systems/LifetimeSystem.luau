return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, lifetime in world:query(Components.Lifetime) do
		local remaining = lifetime.remaining
		if remaining == nil then
			continue
		end

		remaining -= dt
		if remaining <= 0 then
			world:delete(entity)
		else
			lifetime.remaining = remaining
			world:set(entity, Components.Lifetime, lifetime)
		end
	end
end
