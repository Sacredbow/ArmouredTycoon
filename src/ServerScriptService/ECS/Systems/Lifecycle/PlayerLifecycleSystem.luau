--!strict
--[[
	Processes typed player lifecycle components. Spawn protection and highlight
	fade no longer travel through a generic task dispatcher.
]]
const TweenService = game:GetService("TweenService")
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const Dt = Context.dt
	for Entity, Protection in World:query(Components.SpawnProtection) do
		const Character = Protection.Character
		const Humanoid = Protection.Humanoid
		if not Character or not Character.Parent or not Humanoid or Humanoid.Parent ~= Character then
			World:remove(Entity, Components.SpawnProtection)
			continue
		end
		Protection.Remaining -= Dt
		if Protection.Remaining <= 0 then
			Humanoid.Health = math.min(Humanoid.MaxHealth, 100)
			World:remove(Entity, Components.SpawnProtection)
		else
			World:set(Entity, Components.SpawnProtection, Protection)
		end
	end

	for Entity, Fade in World:query(Components.SpawnHighlight) do
		const Highlight = Fade.Highlight
		if not Highlight or not Highlight.Parent then
			World:remove(Entity, Components.SpawnHighlight)
			continue
		end
		Fade.Remaining -= Dt
		if Fade.Remaining <= 0 then
			const FadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine)
			TweenService:Create(Highlight, FadeInfo, { FillTransparency = 1 }):Play()
			const OutlineTween = TweenService:Create(Highlight, FadeInfo, { OutlineTransparency = 1 })
			OutlineTween.Completed:Once(function()
				if Highlight.Parent then
					Highlight:Destroy()
				end
			end)
			OutlineTween:Play()
			World:remove(Entity, Components.SpawnHighlight)
		else
			World:set(Entity, Components.SpawnHighlight, Fade)
		end
	end
end
