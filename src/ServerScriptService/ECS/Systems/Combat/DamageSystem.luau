--!strict
--[[
	@class DamageSystem

	@desc
	Processes DamageRequest entities â€” applies damage to humanoids,
	tracks the last damager for kill credit, and cleans up request entities.
]]

--// Services

const Players = game:GetService("Players")
const ServerScriptService = game:GetService("ServerScriptService")
--// Modules

const DamageRuntimeState = require(ServerScriptService.Services.Combat.DamageRuntimeState)
--// Module

return function(context: any)
	const World = context.world
	const Components = context.Components
	for Entity, DamageRequest in World:query(Components.DamageRequest) do
		const Humanoid = DamageRequest.humanoid
		const Attacker = DamageRequest.attacker
		const Amount = DamageRequest.amount
		if Humanoid and Humanoid.Parent and Humanoid.Health > 0 and Amount and Amount > 0 then
			-- Never award kill credit for self-inflicted damage (anti-farming).
			if Attacker and Attacker.Character ~= Humanoid.Parent then
				const CreatorTag = Instance.new("ObjectValue")
				CreatorTag.Name = "creator"
				CreatorTag.Value = Attacker
				CreatorTag.Parent = Humanoid
				const TagEntity = World:entity()
				World:set(TagEntity, Components.CreatorTagLifetime, { Tag = CreatorTag, Remaining = 1 })

				DamageRuntimeState.SetLastDamager(Humanoid, Attacker.UserId)
			end

			Humanoid:TakeDamage(Amount)
		end

		World:delete(Entity)
	end
end
