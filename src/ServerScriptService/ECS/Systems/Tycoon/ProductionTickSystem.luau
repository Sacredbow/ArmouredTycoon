--!strict
--[[
	@class ProductionTickSystem

	@desc
	Processes Producer entities — accumulates production ticks, creates
	dropper visuals, and adds collector cash. Cleans up orphaned droppers.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, Producer in World:query(Components.Producer) do
		if Producer.paused == true then
			continue
		end

		Producer.elapsed = (Producer.elapsed or 0) + dt

		if Producer.elapsed >= Producer.interval then
			Producer.elapsed -= Producer.interval

			const Tycoon = Producer.tycoon
			const Dropper = Producer.dropper
			const SpawnPart = Producer.spawnPart

			if not Tycoon or not Dropper or not Dropper.Parent or not SpawnPart or not SpawnPart.Parent then
				World:delete(Entity)
				continue
			end

			Tycoon:_CreateDropperVisual(Dropper, SpawnPart)
			Tycoon:_AddCollectorAmount(Producer.value)
		end

		World:set(Entity, Components.Producer, Producer)
	end
end
