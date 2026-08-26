--!strict
--[[
	@class RevealSystem

	@desc
	Animates revealed items (build purchases) — applies fade-step
	progress over time and fires onComplete when the reveal finishes.
]]

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, Reveal in World:query(Components.Reveal) do
		const Item = Reveal.item
		if not Item or not Item.Parent then
			World:remove(Entity, Components.Reveal)
			continue
		end

		Reveal.elapsed = math.min((Reveal.elapsed or 0) + dt, Reveal.duration)
		const Progress = if Reveal.duration > 0 then Reveal.elapsed / Reveal.duration else 1

		const Tycoon = Reveal.tycoon
		if Tycoon then
			for _, Target in ipairs(Reveal.targets) do
				if Target.Parent or Target == Item then
					Tycoon:_ApplyFadeStep(Target, Progress)
				end
			end
		end

		if Progress >= 1 then
			World:remove(Entity, Components.Reveal)

			if Reveal.onComplete then
				Reveal.onComplete()
			end
		else
			World:set(Entity, Components.Reveal, Reveal)
		end
	end
end
