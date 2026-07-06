return function(context)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, reveal in world:query(Components.Reveal) do
		local item = reveal.item
		if not item or not item.Parent then
			world:remove(entity, Components.Reveal)
			continue
		end

		reveal.elapsed = math.min((reveal.elapsed or 0) + dt, reveal.duration)
		local progress = if reveal.duration > 0 then reveal.elapsed / reveal.duration else 1

		local tycoon = reveal.tycoon
		if tycoon then
			for _, target in ipairs(reveal.targets) do
				if target.Parent or target == item then
					tycoon:_ApplyFadeStep(target, progress)
				end
			end
		end

		if progress >= 1 then
			world:remove(entity, Components.Reveal)

			local onComplete = reveal.onComplete
			if onComplete then
				onComplete()
			end
		else
			world:set(entity, Components.Reveal, reveal)
		end
	end
end
