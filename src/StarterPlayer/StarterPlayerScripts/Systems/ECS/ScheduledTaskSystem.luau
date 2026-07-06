return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, scheduledTask in world:query(Components.ScheduledTask) do
		scheduledTask.elapsed = (scheduledTask.elapsed or 0) + dt

		if scheduledTask.elapsed >= scheduledTask.delay then
			local callback = scheduledTask.callback
			local keepRunning = true
			if callback then
				keepRunning = callback() ~= false
			end

			if scheduledTask.repeatEvery and keepRunning then
				scheduledTask.elapsed = 0
				scheduledTask.delay = scheduledTask.repeatEvery
				world:set(entity, Components.ScheduledTask, scheduledTask)
			else
				world:delete(entity)
			end
		else
			world:set(entity, Components.ScheduledTask, scheduledTask)
		end
	end
end
