--!strict
--[[
	@class NPCUpdateSystem

	@desc
	Processes NPCUpdate entities — advances the NPC's state machine
	on a timed interval. Cleans up orphaned or invalid controllers.
]]

--// Modules

const ServerScriptService = game:GetService("ServerScriptService")
const NPCRegistry = require(ServerScriptService.AI.NPCRegistry)
--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, NPCUpdate in World:query(Components.NPCUpdate) do
		const NPCEntity = NPCUpdate.npcEntity or Entity
		const Controller = NPCRegistry.Get(NPCEntity)
		if not Controller or Controller.Destroyed or not Controller.NPC or not Controller.NPC.Parent then
			NPCRegistry.Unregister(NPCEntity)
			World:delete(Entity)
			continue
		end

		NPCUpdate.elapsed = (NPCUpdate.elapsed or 0) + dt
		const Interval = math.max(tonumber(NPCUpdate.interval) or 0.1, 0.05)
		if NPCUpdate.elapsed >= Interval then
			NPCUpdate.elapsed -= Interval
			const StateMachine = Controller.StateMachine
			if StateMachine then
				StateMachine:Update()
			end
		end

		World:set(Entity, Components.NPCUpdate, NPCUpdate)
	end
end
