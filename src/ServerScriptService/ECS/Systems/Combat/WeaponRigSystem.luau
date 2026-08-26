--!strict
--[[
	@class WeaponRigSystem

	@desc
	Cleans up WeaponRig entities when the rig's character, model, or
	animation base is destroyed (weapon unequipped / player left).
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components

	for Entity, WeaponRig in World:query(Components.WeaponRig) do
		const Character = WeaponRig.character
		const Model = WeaponRig.model
		const AnimBase = WeaponRig.animBase

		if not Character or not Character.Parent or not Model or not Model.Parent or not AnimBase or not AnimBase.Parent then
			World:delete(Entity)
		end
	end
end

