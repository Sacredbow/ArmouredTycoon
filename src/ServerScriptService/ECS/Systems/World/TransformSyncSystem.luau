--!strict
--[[
	@class TransformSyncSystem

	@desc
	Syncs Model or BasePart CFrame from an entity's Transform component
	to the actual instance. Used for movement interpolation.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components

	for _, Model, Transform in World:query(Components.Model, Components.Transform) do
		if typeof(Transform) ~= "CFrame" then
			continue
		end

		if typeof(Model) == "Instance" and Model.Parent then
			if Model:IsA("Model") then
				Model:PivotTo(Transform)
			elseif Model:IsA("BasePart") then
				Model.CFrame = Transform
			end
		end
	end
end
