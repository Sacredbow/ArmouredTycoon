local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterRegistry = require(ReplicatedStorage.CharacterUtilities.CharacterRegistry)

return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, character in world:query(Components.Character) do
		local manager = CharacterRegistry.Get(entity)
		if not character or not character.Parent or not manager then
			if manager and manager.Destroy then
				manager:Destroy()
			end

			CharacterRegistry.Unregister(entity)
			world:delete(entity)
			continue
		end

		manager:Update(dt)
	end
end