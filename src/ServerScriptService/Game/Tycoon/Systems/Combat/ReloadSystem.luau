--!strict
const ServerScriptService = game:GetService("ServerScriptService")
const ReloadConfig = require(ServerScriptService.Game.Tycoon.Shared.ReloadConfig)
const Notify = require(ServerScriptService.Game.Tycoon.Shared.NotifyPlayer)
const ValidatePromptRange = require(ServerScriptService.Game.Tycoon.Shared.ValidatePromptRange)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.PromptIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "Reload" then
				const Data = Intent.Data
				const Owner = Data and Data.TycoonEntity and World:get(Data.TycoonEntity, Components.Owner)
				const Lakester = Data and Data.Lakester
				local Prompt = Lakester
					and Lakester:FindFirstChild("Requester")
					and Lakester.Requester:FindFirstChildOfClass("ProximityPrompt") --__STYLUA_CONST__
				if not Owner or Owner.player ~= Player then
					Notify(Player, "error", "Only the tycoon owner can reload here.")
				elseif not Prompt or not ValidatePromptRange(Player, Prompt) then
					Notify(Player, "info", "The reload station is unavailable.")
				else
					ReloadConfig.RefillWeapons(Player)
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
