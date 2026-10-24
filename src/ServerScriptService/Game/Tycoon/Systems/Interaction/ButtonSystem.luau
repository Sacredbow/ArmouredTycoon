--!strict
-- Consumes button contact intents on the ECS runner.
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
			if Intent.Action == "PurchaseButton" then
				const Data = Intent.Data
				if Data and Data.TycoonEntity and Data.Button then
					TycoonRuntime.PurchaseButton(Data.TycoonEntity, Player, Data.Button)
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
