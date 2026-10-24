--!strict
--[[
	Consumes GunPickup intents from the frame loop. Prompt callbacks only append
	data; this system owns validation and cloning.
]]
const ServerStorage = game:GetService("ServerStorage")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const ValidatePromptRange = require(ServerScriptService.Game.Tycoon.Shared.ValidatePromptRange)
const Notify = require(ServerScriptService.Game.Tycoon.Shared.NotifyPlayer)
local function ProcessIntent(World: any, Components: any, Player: Player, Intent: any)
	const Data = Intent.Data
	const TycoonEntity = Data and Data.TycoonEntity
	const GunModel = Data and Data.GunModel
	const Owner = TycoonEntity and World:get(TycoonEntity, Components.Owner)
	if not Owner or Owner.player ~= Player then
		Notify(Player, "error", "Only the tycoon owner can collect this weapon.")
		return
	end

	const Requester = GunModel and GunModel:FindFirstChild("Requester")
	const Prompt = Requester and Requester:FindFirstChildOfClass("ProximityPrompt")
	if not Prompt or not ValidatePromptRange(Player, Prompt) then
		Notify(Player, "info", "Move closer to collect this weapon.")
		return
	end

	const WeaponName = GunModel.Name
	const Character = Player.Character
	if
		Player.Backpack:FindFirstChild(WeaponName)
		or Player.StarterGear:FindFirstChild(WeaponName)
		or (Character and Character:FindFirstChild(WeaponName))
	then
		Notify(Player, "info", "You already have this weapon.")
		return
	end

	const Guns = ServerStorage:FindFirstChild("Guns")
	const Template = Guns and Guns:FindFirstChild(WeaponName)
	if not Template then
		warn(`ServerStorage.Guns is missing the required {WeaponName} template`)
		return
	end
	Template:Clone().Parent = Player.Backpack
end

return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.PromptIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "GunPickup" then
				ProcessIntent(World, Components, Player, Intent)
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
