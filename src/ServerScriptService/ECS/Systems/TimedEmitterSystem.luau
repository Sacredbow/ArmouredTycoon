return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, timedEmitter in world:query(Components.TimedEmitter) do
		timedEmitter.age = (timedEmitter.age or 0) + dt
		timedEmitter.elapsed = (timedEmitter.elapsed or 0) + dt

		while timedEmitter.elapsed >= timedEmitter.interval do
			timedEmitter.elapsed -= timedEmitter.interval

			for _, emitter in ipairs(timedEmitter.emitters) do
				if emitter.Parent then
					emitter:Emit(timedEmitter.amount)
				end
			end
		end

		if timedEmitter.age >= timedEmitter.duration then
			local destroyAfter = timedEmitter.destroyAfter
			if destroyAfter and destroyAfter.Parent then
				destroyAfter:Destroy()
			end

			world:delete(entity)
		else
			world:set(entity, Components.TimedEmitter, timedEmitter)
		end
	end
end
