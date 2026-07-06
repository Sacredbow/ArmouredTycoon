return function(context)
	local world = context.world
	local Components = context.Components

	for _, model, transform in world:query(Components.Model, Components.Transform) do
		if typeof(transform) ~= "CFrame" then
			continue
		end

		if typeof(model) == "Instance" and model.Parent then
			if model:IsA("Model") then
				model:PivotTo(transform)
			elseif model:IsA("BasePart") then
				model.CFrame = transform
			end
		end
	end
end
