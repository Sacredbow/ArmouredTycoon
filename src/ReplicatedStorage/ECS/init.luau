--!strict
--[[
	@class ECS

	@desc
	Minimal jecs wrapper. Owns the shared ECS world (server + client),
	defines every component ahead of time, and exposes typed helpers
	for entity/component CRUD. The returned table and component map are
	frozen to prevent accidental mutation at runtime.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const jecs = require(ReplicatedStorage.Packages.jecs)

--// Constants

const ComponentNames = {
	"Name",
	"Model",
	"Owner",
	"Tycoon",
	"Transform",
	"Velocity",
	"Health",
	"Lifetime",
	"Producer",
	"Projectile",
	"Raycast",
	"PreviousPosition",
	"BuildItem",
	"Button",
	"Reveal",
	"Purchased",
	"Character",
	"CharacterManager",
	"RocketFlight",
	"TimedEmitter",
	"DamageRequest",
	"WeaponRig",
	"StanceState",
	"NPCUpdate",
	"ScheduledTask",
	"EnvironmentClock",
}

--// Module

const World = jecs.World.new()
const Components: { [string]: any } = {}

for _, Name in ComponentNames do
	Components[Name] = World:component()
end

const ECS = {}

ECS.jecs = jecs
ECS.world = World
ECS.Components = table.freeze(Components)

--// Public API

function ECS.createEntity(ComponentData: { [string]: any }?): number
	const Entity = World:entity()

	if ComponentData then
		for ComponentName, Value in ComponentData do
			const Component = Components[ComponentName]
			if Component then
				World:set(Entity, Component, Value)
			else
				warn(`[ECS] Unknown component "{ComponentName}"`)
			end
		end
	end

	return Entity
end

function ECS.deleteEntity(Entity: number)
	World:delete(Entity)
end

function ECS.set(Entity: number, ComponentName: string, Value: any)
	const Component = Components[ComponentName]
	if not Component then
		error(`[ECS] Unknown component "{ComponentName}"`)
	end

	World:set(Entity, Component, Value)
end

function ECS.add(Entity: number, ComponentName: string)
	const Component = Components[ComponentName]
	if not Component then
		error(`[ECS] Unknown component "{ComponentName}"`)
	end

	World:add(Entity, Component)
end

function ECS.remove(Entity: number, ComponentName: string)
	const Component = Components[ComponentName]
	if not Component then
		error(`[ECS] Unknown component "{ComponentName}"`)
	end

	World:remove(Entity, Component)
end

function ECS.get(Entity: number, ComponentName: string): any
	const Component = Components[ComponentName]
	if not Component then
		error(`[ECS] Unknown component "{ComponentName}"`)
	end

	return World:get(Entity, Component)
end

return table.freeze(ECS)
