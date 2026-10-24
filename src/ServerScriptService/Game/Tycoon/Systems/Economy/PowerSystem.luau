--!strict
const CollectionService = game:GetService("CollectionService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const Factory = require(ServerScriptService.Game.Tycoon.TycoonFactory)
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const ValidatePromptRange = require(ServerScriptService.Game.Tycoon.Shared.ValidatePromptRange)
local function Toast(Player: Player, Kind: string, Message: string)
	Packets.packets.Notification.sendTo({ ["type"] = Kind, message = Message }, Player)
end

local function EnableElectricity(Hierarchy: any)
	const Purchased = Hierarchy.PurchasedItems
	if not Purchased then
		return
	end
	for _, Part in Purchased:GetDescendants() do
		if Part:IsA("BasePart") and Part:FindFirstChild("SwitchLight") then
			Part.Material = Enum.Material.Neon
			Part.BrickColor = BrickColor.new("Institutional white")
		elseif Part:IsA("PointLight") then
			Part.Brightness = 0.09
		elseif CollectionService:HasTag(Part, "ElectricityParts") and Part:IsA("BasePart") then
			Part.Material = Enum.Material.Neon
		elseif CollectionService:HasTag(Part, "Power") and Part:IsA("ParticleEmitter") then
			Part.Enabled = true
		end
	end
end

return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.PromptIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "RestorePower" then
				const Data = Intent.Data
				const TycoonEntity = Data and Data.TycoonEntity
				const Owner = TycoonEntity and World:get(TycoonEntity, Components.Owner)
				const State = TycoonEntity and World:get(TycoonEntity, Components.TycoonState)
				const Hierarchy = TycoonEntity and World:get(TycoonEntity, Components.Hierarchy)
				if not Owner or Owner.player ~= Player or not State or not Hierarchy then
					Toast(Player, "error", "Only the tycoon owner can restore power.")
				elseif not Data.Prompt or not ValidatePromptRange(Player, Data.Prompt) then
					Toast(Player, "info", "Move closer to the fuse box.")
				elseif State.power then
					Toast(Player, "info", "Power is already on")
				elseif not Hierarchy.PurchasedItems:FindFirstChild("1b") then
					Toast(Player, "info", "Find the wires first")
				else
					State.power = true
					World:set(TycoonEntity, Components.TycoonState, State)
					EnableElectricity(Hierarchy)
					Toast(Player, "success", "Power restored")
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
