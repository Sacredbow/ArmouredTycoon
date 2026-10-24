--!strict
-- Removes temporary creator tags through the ECS frame loop.
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	for Entity, Lifetime in World:query(Components.CreatorTagLifetime) do
		Lifetime.Remaining -= DeltaTime
		if Lifetime.Remaining <= 0 then
			const Tag = Lifetime.Tag
			if Tag and Tag.Parent then
				Tag:Destroy()
			end
			World:delete(Entity)
		else
			World:set(Entity, Components.CreatorTagLifetime, Lifetime)
		end
	end
end
