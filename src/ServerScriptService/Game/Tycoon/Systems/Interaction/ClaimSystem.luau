--!strict
-- Claims are contact intents consumed on the ECS runner.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const TycoonRuntime = require(ServerScriptService.Game.Tycoon.TycoonCoordinator)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.ContactIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "ClaimTycoon" then
				const Data = Intent.Data
				const TycoonEntity = Data and Data.TycoonEntity
				const Owner = TycoonEntity and World:get(TycoonEntity, Components.Owner)
				if (not Owner or not Owner.player) and TycoonEntity then
					TycoonRuntime.Claim(TycoonEntity, Player)
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
