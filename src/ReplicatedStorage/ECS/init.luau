local ReplicatedStorage = game:GetService("ReplicatedStorage")

local jecs = require(ReplicatedStorage.Packages.jecs)

local world = jecs.World.new()

local Components = {
	Name = world:component(),
	Model = world:component(),
	Owner = world:component(),
	Tycoon = world:component(),
	Transform = world:component(),
	Velocity = world:component(),
	Health = world:component(),
	Lifetime = world:component(),
	Producer = world:component(),
	Projectile = world:component(),
	Raycast = world:component(),
	PreviousPosition = world:component(),
	BuildItem = world:component(),
	Button = world:component(),
	Reveal = world:component(),
	Purchased = world:component(),
	Character = world:component(),
	CharacterManager = world:component(),
	RocketFlight = world:component(),
	TimedEmitter = world:component(),
	DamageRequest = world:component(),
	WeaponRig = world:component(),
	StanceState = world:component(),
	NPCUpdate = world:component(),
	ScheduledTask = world:component(),
	EnvironmentClock = world:component(),
}

local ECS = {}

ECS.jecs = jecs
ECS.world = world
ECS.Components = table.freeze(Components)

function ECS.createEntity(componentData: {[string]: any}?): number
	local entity = world:entity()

	if componentData then
		for componentName, value in pairs(componentData) do
			local component = Components[componentName]
			if component then
				world:set(entity, component, value)
			else
				warn(`[ECS] Unknown component "{componentName}"`)
			end
		end
	end

	return entity
end

function ECS.deleteEntity(entity: number)
	world:delete(entity)
end

function ECS.set(entity: number, componentName: string, value: any)
	local component = Components[componentName]
	if not component then
		error(`[ECS] Unknown component "{componentName}"`)
	end

	world:set(entity, component, value)
end

function ECS.add(entity: number, componentName: string)
	local component = Components[componentName]
	if not component then
		error(`[ECS] Unknown component "{componentName}"`)
	end

	world:add(entity, component)
end

function ECS.remove(entity: number, componentName: string)
	local component = Components[componentName]
	if not component then
		error(`[ECS] Unknown component "{componentName}"`)
	end

	world:remove(entity, component)
end

function ECS.get(entity: number, componentName: string): any
	local component = Components[componentName]
	if not component then
		error(`[ECS] Unknown component "{componentName}"`)
	end

	return world:get(entity, component)
end

return table.freeze(ECS)
