--!strict
--[[
	Applies delayed electricity impacts and clears the Electrified component.
	Each timer is a typed component on the player's ECS entity.
]]
const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RagdollModule = require(ServerScriptService.Modules.RagdollModule)
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const Dt = Context.dt
	for Entity, Player, Impact in World:query(Components.PlayerRef, Components.ElectricityImpact) do
		Impact.Remaining -= Dt
		if Impact.Remaining > 0 then
			World:set(Entity, Components.ElectricityImpact, Impact)
			continue
		end
		const Owner = World:get(Impact.TycoonEntity, Components.Owner)
		const Character = Impact.Character
		const Humanoid = Impact.Humanoid
		if
			Player.Parent
			and Character
			and Character.Parent
			and Player.Character == Character
			and Humanoid
			and Humanoid.Parent == Character
			and Humanoid.Health > 0
			and Owner
			and Owner.generation == Impact.OwnerGeneration
		then
			const DamageEntity = World:entity()
			World:set(
				DamageEntity,
				Components.DamageRequest,
				{ humanoid = Humanoid, amount = 60, source = Impact.SourceModel }
			)
			RagdollModule.Ragdoll(Player, 4)
			Packets.packets.Notification.sendTo({ ["type"] = "error", message = "You were electrocuted" }, Player)
		end
		World:remove(Entity, Components.ElectricityImpact)
	end

	for Entity, Cooldown in World:query(Components.ElectricityCooldown) do
		Cooldown.Remaining -= Dt
		if Cooldown.Remaining <= 0 then
			World:remove(Entity, Components.ElectricityCooldown)
			World:remove(Entity, Components.Electrified)
		else
			World:set(Entity, Components.ElectricityCooldown, Cooldown)
		end
	end
end
