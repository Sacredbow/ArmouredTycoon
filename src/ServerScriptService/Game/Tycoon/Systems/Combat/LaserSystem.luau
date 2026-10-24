--!strict
-- Consumes LaserHit contact intents on the ECS frame.
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.ContactIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "LaserHit" then
				const Data = Intent.Data
				const Owner = Data and Data.TycoonEntity and World:get(Data.TycoonEntity, Components.Owner)
				const Laser = Data and Data.Laser
				const Character = Player.Character
				const Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
				if Laser and Laser.Transparency == 0 and (not Owner or Owner.player ~= Player) and Humanoid then
					Humanoid:TakeDamage(math.huge)
				end
			else
				Remaining[#Remaining + 1] = Intent
			end
		end
		if #Remaining == 0 then
			World:remove(Entity, Components.ContactIntent)
		else
			World:set(Entity, Components.ContactIntent, Remaining)
		end
	end
end
