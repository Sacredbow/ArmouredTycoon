--!strict
-- Tracks nuke recharge as a typed component on the launcher tycoon.
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	for Entity, Cooldown in World:query(Components.NukeCooldown) do
		Cooldown.Remaining -= DeltaTime
		if Cooldown.Remaining > 0 then
			World:set(Entity, Components.NukeCooldown, Cooldown)
			continue
		end

		const State = World:get(Entity, Components.TycoonState)
		if State then
			State.nukeCooldownReady = true
			World:set(Entity, Components.TycoonState, State)
		end
		const Button = Cooldown.Button
		if Button and Button.Parent and Button:IsA("BasePart") then
			Button.BrickColor = BrickColor.new("Bright green")
		end
		World:remove(Entity, Components.NukeCooldown)
	end
end
