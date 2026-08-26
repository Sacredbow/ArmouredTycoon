--!strict
--[[
	@class ScheduledTaskSystem

	@desc
	Processes ScheduledTask entities — fires callbacks after a delay,
	supports optional repeatEvery for recurring tasks, and cleans up
	completed or expired tasks.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, ScheduledTask in World:query(Components.ScheduledTask) do
		ScheduledTask.elapsed = (ScheduledTask.elapsed or 0) + dt

		if ScheduledTask.elapsed >= ScheduledTask.delay then
			const Callback = ScheduledTask.callback
			const KeepRunning = if Callback then Callback() ~= false else true

			if ScheduledTask.repeatEvery and KeepRunning then
				ScheduledTask.elapsed = 0
				ScheduledTask.delay = ScheduledTask.repeatEvery
				World:set(Entity, Components.ScheduledTask, ScheduledTask)
			else
				World:delete(Entity)
			end
		else
			World:set(Entity, Components.ScheduledTask, ScheduledTask)
		end
	end
end
