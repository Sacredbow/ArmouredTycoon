--!strict
-- Shared ECS lookups for the Tycoon domain.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Shared.Core.ECS)

local Queries = {}

function Queries.FindPlayerEntity(Player: Player): number?
	for Entity, PlayerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if PlayerRef == Player then
			return Entity
		end
	end
	return nil
end

function Queries.FindOwnedTycoon(Player: Player): number?
	for Entity, OwnerData in ECS.world:query(ECS.Components.Owner) do
		if OwnerData.player == Player then
			return Entity
		end
	end
	return nil
end

function Queries.FindAvailableTycoon(): number?
	for Entity, State in ECS.world:query(ECS.Components.TycoonState) do
		if State.active ~= false and not State.owner then
			return Entity
		end
	end
	return nil
end

function Queries.GetTycoonModel(Entity: number): Model?
	return ECS.world:get(Entity, ECS.Components.ModelRef)
end

function Queries.GetAllTycoons(): { number }
	local Entities = {}
	for Entity, State in ECS.world:query(ECS.Components.TycoonState) do
		if State.active ~= false then
			Entities[#Entities + 1] = Entity
		end
	end
	return Entities
end

return Queries
