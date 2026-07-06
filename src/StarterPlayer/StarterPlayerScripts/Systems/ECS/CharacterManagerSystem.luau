return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, character, manager in world:query(Components.Character, Components.CharacterManager) do
		if not character or not character.Parent then
			if manager and manager.Destroy then
				manager:Destroy()
			end

			world:delete(entity)
			continue
		end

		manager:Update(dt)
	end
end
