--!strict
-- Typed character and NPC timers consumed by the ECS runner.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const NPCRegistry = require(ServerScriptService.AI.NPCRegistry)
const RagdollModule = require(ServerScriptService.Modules.Ragdoll)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	for Entity, Timer in World:query(Components.NPCRespawn) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining <= 0 then
			const Controller = NPCRegistry.Get(Timer.NPCEntity)
			if Controller then
				Controller:CharacterPool()
			end
			World:delete(Entity)
		else
			World:set(Entity, Components.NPCRespawn, Timer)
		end
	end

	for Entity, Timer in World:query(Components.RagdollRestore) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining <= 0 then
			const Character = Timer.Character
			if Character and Character.Parent then
				RagdollModule.RestoreScheduled(Character, Timer.Sockets, Timer.Motors)
			end
			World:delete(Entity)
		else
			World:set(Entity, Components.RagdollRestore, Timer)
		end
	end
end
