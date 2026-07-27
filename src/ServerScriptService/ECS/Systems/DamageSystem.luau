local ServerScriptService = game:GetService("ServerScriptService")

local DamageRuntimeState = require(ServerScriptService.Services.Combat.DamageRuntimeState)

return function(context)


	local world = context.world
	local Components = context.Components

	for entity, damageRequest in world:query(Components.DamageRequest) do
		local humanoid = damageRequest.humanoid
		local attacker = damageRequest.attacker
		local amount = damageRequest.amount

		if humanoid and humanoid.Parent and humanoid.Health > 0 and amount and amount > 0 then
			if attacker then
				local creatorTag = Instance.new("ObjectValue")
				creatorTag.Name = "creator"
				creatorTag.Value = attacker
				creatorTag.Parent = humanoid
				task.delay(1, function()
					if creatorTag.Parent then
						creatorTag:Destroy()
					end
				end)

				DamageRuntimeState.SetLastDamager(humanoid, attacker.UserId)
			end

			humanoid:TakeDamage(amount)
		end

		world:delete(entity)
	end
end
