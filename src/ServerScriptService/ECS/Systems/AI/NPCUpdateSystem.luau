--!strict
--[[
	@class NPCUpdateSystem

	@desc
	Processes NPCUpdate entities — advances the NPC's state machine
	on a timed interval. Cleans up orphaned or invalid controllers.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, NPCUpdate in World:query(Components.NPCUpdate) do
		const Controller = NPCUpdate.controller
		if not Controller or not Controller.NPC or not Controller.NPC.Parent then
			if Controller then
				Controller.StateThreadRunning = false
				Controller.ECSEntity = nil
			end
			World:delete(Entity)
			continue
		end

		NPCUpdate.elapsed = (NPCUpdate.elapsed or 0) + dt
		if NPCUpdate.elapsed >= NPCUpdate.interval then
			NPCUpdate.elapsed -= NPCUpdate.interval
			const StateMachine = Controller.StateMachine
			if StateMachine then
				StateMachine:Update()
			end
		end

		World:set(Entity, Components.NPCUpdate, NPCUpdate)
	end
end
