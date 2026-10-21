--!strict
--[[
	@class CharacterRegistry

	Transitional client lifecycle boundary for CharacterManager facades. ECS
	components keep only the numeric entity id; the mutable manager remains
	outside the world and is resolved by systems at the boundary.
]]

local Registry: { [number]: any } = {}

local CharacterRegistry = {}

function CharacterRegistry.Register(Entity: number, Manager: any)
	Registry[Entity] = Manager
end

function CharacterRegistry.Get(Entity: number): any?
	return Registry[Entity]
end

function CharacterRegistry.Unregister(Entity: number)
	Registry[Entity] = nil
end

return CharacterRegistry