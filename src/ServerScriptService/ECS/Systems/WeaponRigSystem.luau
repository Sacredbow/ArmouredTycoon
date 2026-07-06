return function(context)
	local world = context.world
	local Components = context.Components

	for entity, weaponRig in world:query(Components.WeaponRig) do
		local character = weaponRig.character
		local model = weaponRig.model
		local animBase = weaponRig.animBase

		if not character or not character.Parent or not model or not model.Parent or not animBase or not animBase.Parent then
			world:delete(entity)
		end
	end
end
