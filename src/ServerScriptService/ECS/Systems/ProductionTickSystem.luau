return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, producer in world:query(Components.Producer) do
		if producer.paused == true then
			continue
		end

		producer.elapsed = (producer.elapsed or 0) + dt

		if producer.elapsed >= producer.interval then
			producer.elapsed -= producer.interval

			local tycoon = producer.tycoon
			local dropper = producer.dropper
			local spawnPart = producer.spawnPart

			if not tycoon or not dropper or not dropper.Parent or not spawnPart or not spawnPart.Parent then
				world:delete(entity)
				continue
			end

			tycoon:_CreateDropperVisual(dropper, spawnPart)
			tycoon:_AddCollectorAmount(producer.value)
		end

		world:set(entity, Components.Producer, producer)
	end
end
