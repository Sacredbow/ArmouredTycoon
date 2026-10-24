--!strict
-- Nuke interactions are intents and the active cinematic is advanced by ECS timers.
const ServerScriptService = game:GetService("ServerScriptService")
const NukeService = require(ServerScriptService.Services.World.NukeService)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	for Entity in World:query(Components.NukeSession) do
		NukeService.AdvanceActive(Entity, DeltaTime)
	end

	for Entity, Impact in World:query(Components.NukeImpact) do
		Impact.Remaining -= DeltaTime
		if Impact.Remaining <= 0 then
			NukeService.ProcessImpactActive(Impact.TargetEntity, Impact.TargetPlayer, Impact.Generation)
			World:remove(Entity, Components.NukeImpact)
		else
			World:set(Entity, Components.NukeImpact, Impact)
		end
	end

	for Entity, Ending in World:query(Components.NukeEnd) do
		Ending.Remaining -= DeltaTime
		if Ending.Remaining <= 0 then
			NukeService.SendEndActive(Ending.SessionId)
			World:remove(Entity, Components.NukeEnd)
		else
			World:set(Entity, Components.NukeEnd, Ending)
		end
	end

	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.PromptIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "NukeLaunch" then
				const Data = Intent.Data
				if Data and Data.TycoonEntity and Data.Prompt then
					NukeService.StartActive(Data.TycoonEntity, Player, Data.Prompt)
				end
			else
				Remaining[#Remaining + 1] = Intent
			end
		end
		if #Remaining == 0 then
			World:remove(Entity, Components.PromptIntent)
		else
			World:set(Entity, Components.PromptIntent, Remaining)
		end
	end
end
