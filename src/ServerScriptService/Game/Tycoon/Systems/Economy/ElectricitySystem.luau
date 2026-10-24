--!strict
-- Consumes electricity contact intents during the ECS frame.
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const Factory = require(ServerScriptService.Game.Tycoon.TycoonFactory)
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const ELECTRIFY_IMPACT_DELAY = 0.3
const ELECTRIFY_COOLDOWN = 5
local function Toast(Player: Player, Kind: string, Message: string)
	Packets.packets.Notification.sendTo({ ["type"] = Kind, message = Message }, Player)
end

local function FindPlayerEntity(World: any, Components: any, Player: Player): number?
	for Entity, PlayerRef in World:query(Components.PlayerRef) do
		if PlayerRef == Player then
			return Entity
		end
	end
	return nil
end

local function Electrify(World: any, Components: any, TycoonEntity: number, Player: Player, OwnerGeneration: number)
	const Entity = FindPlayerEntity(World, Components, Player)
	if not Entity or World:get(Entity, Components.Electrified) == true then
		return
	end
	const Character = Player.Character
	const Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Character or not Humanoid then
		return
	end
	World:set(Entity, Components.Electrified, true)
	Humanoid:UnequipTools()
	World:set(Entity, Components.ElectricityImpact, {
		Remaining = ELECTRIFY_IMPACT_DELAY,
		Character = Character,
		Humanoid = Humanoid,
		TycoonEntity = TycoonEntity,
		OwnerGeneration = OwnerGeneration,
		SourceModel = Factory.GetModel(TycoonEntity),
	})
	World:set(Entity, Components.ElectricityCooldown, { Remaining = ELECTRIFY_COOLDOWN })
end

return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.ContactIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "ElectricityHit" then
				const Data = Intent.Data
				const TycoonEntity = Data and Data.TycoonEntity
				const OwnerData = TycoonEntity and World:get(TycoonEntity, Components.Owner)
				const TycoonState = TycoonEntity and Factory.GetState(TycoonEntity)
				const OwnerPlayer = OwnerData and OwnerData.player
				if TycoonEntity and OwnerPlayer and TycoonState and TycoonState.power and OwnerPlayer ~= Player then
					Electrify(World, Components, TycoonEntity, Player, OwnerData.generation or 0)
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
