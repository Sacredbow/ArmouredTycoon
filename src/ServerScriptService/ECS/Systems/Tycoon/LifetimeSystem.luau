--!strict
--[[
	@class LifetimeSystem

	@desc
	Counts down entity lifetimes and deletes them when time expires.
	Used for temporary visual effects, cleanup timers, etc.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, Lifetime in World:query(Components.Lifetime) do
		const Remaining = Lifetime.remaining
		if Remaining == nil then
			continue
		end

		Lifetime.remaining = Remaining - dt
		if Lifetime.remaining <= 0 then
			World:delete(Entity)
		else
			World:set(Entity, Components.Lifetime, Lifetime)
		end
	end
end
