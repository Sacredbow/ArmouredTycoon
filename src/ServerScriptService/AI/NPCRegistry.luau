--!strict
--[[
	@class NPCRegistry
	Transitional lifecycle boundary for NPC facades. ECS components store only
	the numeric NPC entity id; simulation behavior remains in NPC systems.
]]
local Registry: { [number]: any } = {}
local NPCRegistry = {}

function NPCRegistry.Register(Entity: number, Controller: any)
	Registry[Entity] = Controller
end

function NPCRegistry.Get(Entity: number): any?
	return Registry[Entity]
end

function NPCRegistry.Unregister(Entity: number)
	Registry[Entity] = nil
end

return NPCRegistry