--!strict
-- Processes rarity box lifetime, spawn timers, and claim intents.
const ServerScriptService = game:GetService("ServerScriptService")
const RarityBoxService = require(ServerScriptService.Services.World.RarityBoxService)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	for Entity, Lifetime in World:query(Components.RarityBoxLifetime) do
		Lifetime.Remaining -= DeltaTime
		const Box = Lifetime.Box
		if Lifetime.Remaining <= 0 then
			if Box and Box.Parent then
				Box:Destroy()
			end
			World:delete(Entity)
		else
			World:set(Entity, Components.RarityBoxLifetime, Lifetime)
		end
	end

	for Entity, Timer in World:query(Components.RarityBoxSpawner) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining <= 0 then
			if RarityBoxService.SpawnActive() then
				Timer.Remaining = 60
			end
		end
		World:set(Entity, Components.RarityBoxSpawner, Timer)
	end

	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.ContactIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "RarityBoxClaim" then
				const Data = Intent.Data
				if Data and Data.BoxEntity then
					RarityBoxService.CollectActive(Data.BoxEntity, Player)
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
