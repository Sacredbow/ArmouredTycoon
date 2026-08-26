--!strict
--[[
	@class TimedEmitterSystem

	@desc
	Fires ParticleEmitter bursts on a timed interval. Destroys the
	optional associated instance and cleans up after the duration.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, TimedEmitter in World:query(Components.TimedEmitter) do
		TimedEmitter.age = (TimedEmitter.age or 0) + dt
		TimedEmitter.elapsed = (TimedEmitter.elapsed or 0) + dt

		while TimedEmitter.elapsed >= TimedEmitter.interval do
			TimedEmitter.elapsed -= TimedEmitter.interval

			for _, Emitter in ipairs(TimedEmitter.emitters) do
				if Emitter.Parent then
					Emitter:Emit(TimedEmitter.amount)
				end
			end
		end

		if TimedEmitter.age >= TimedEmitter.duration then
			const DestroyAfter = TimedEmitter.destroyAfter
			if DestroyAfter and DestroyAfter.Parent then
				DestroyAfter:Destroy()
			end

			World:delete(Entity)
		else
			World:set(Entity, Components.TimedEmitter, TimedEmitter)
		end
	end
end
