return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, npcUpdate in world:query(Components.NPCUpdate) do
		local controller = npcUpdate.controller
		if not controller or not controller.NPC or not controller.NPC.Parent then
			if controller then
				controller.StateThreadRunning = false
				controller.ECSEntity = nil
			end
			world:delete(entity)
			continue
		end

		npcUpdate.elapsed = (npcUpdate.elapsed or 0) + dt
		if npcUpdate.elapsed >= npcUpdate.interval then
			npcUpdate.elapsed -= npcUpdate.interval
			local stateMachine = controller.StateMachine
			if stateMachine then
				stateMachine:Update()
			end
		end

		world:set(entity, Components.NPCUpdate, npcUpdate)
	end
end
