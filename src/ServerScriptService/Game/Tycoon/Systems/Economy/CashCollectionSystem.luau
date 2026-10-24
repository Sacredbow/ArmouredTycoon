--!strict
const ServerScriptService = game:GetService("ServerScriptService")
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const Notify = require(ServerScriptService.Game.Tycoon.Shared.NotifyPlayer)
const ValidatePromptRange = require(ServerScriptService.Game.Tycoon.Shared.ValidatePromptRange)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.PromptIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "CollectCash" then
				const TycoonEntity = Intent.Data and Intent.Data.TycoonEntity
				const Owner = TycoonEntity and World:get(TycoonEntity, Components.Owner)
				const State = TycoonEntity and World:get(TycoonEntity, Components.TycoonState)
				const Prompt = Intent.Data and Intent.Data.Prompt
				if not Owner or Owner.player ~= Player or not State then
					Notify(Player, "error", "Only the tycoon owner can collect this cash.")
				elseif not Prompt or not ValidatePromptRange(Player, Prompt) then
					Notify(Player, "info", "Move closer to collect this cash.")
				elseif (State.collectorAmount or 0) <= 0 then
					Notify(Player, "info", "There is no cash to collect yet.")
				else
					const Amount = State.collectorAmount * (if World:get(Entity, Components.X2) == true then 2 else 1)
					State.collectorAmount = 0
					State.displayUpdatePending = false
					World:set(TycoonEntity, Components.TycoonState, State)
					if State.collectorDisplayLabel and State.collectorDisplayLabel.Parent then
						State.collectorDisplayLabel.Text = "0"
					end
					ProfileManager.AddCash(Player, Amount)
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
