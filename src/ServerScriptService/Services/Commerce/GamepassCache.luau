--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ECS = require(ReplicatedStorage.Shared.Core.ECS)

local GamepassCache = {}
local GamepassIds: { [string]: number } = {}

local function FindPlayerEntity(Player: Player): number?
	for Entity, PlayerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if PlayerRef == Player then
			return Entity
		end
	end
	return nil
end

function GamepassCache.Configure(Definitions: { [string]: number })
	table.clear(GamepassIds)
	for Key, GamepassId in Definitions do
		GamepassIds[Key] = GamepassId
	end
end

function GamepassCache.Warm(Player: Player)
	if not Player.Parent then
		return
	end

	for _, GamepassId in GamepassIds do
		local Success, Message = pcall(function()
			GamepassCache.Refresh(Player, GamepassId)
		end)
		if not Success then
			warn(`[GamepassCache] Ownership check failed for {Player.Name}, pass {GamepassId}: {Message}`)
		end
	end
end

function GamepassCache.Refresh(Player: Player, GamepassId: number): boolean?
	if not Player.Parent then
		return nil
	end

	local OwnsPass = MarketplaceService:UserOwnsGamePassAsync(Player.UserId, GamepassId)
	if not Player.Parent then
		return nil
	end

	GamepassCache.SetOwned(Player, GamepassId, OwnsPass)
	return OwnsPass
end

function GamepassCache.GetOwnership(Player: Player, GamepassId: number): boolean?
	local Entity = FindPlayerEntity(Player)
	local Ownership = Entity and ECS.world:get(Entity, ECS.Components.GamepassOwnership)
	return Ownership and Ownership[GamepassId]
end

function GamepassCache.Has(Player: Player, GamepassId: number): boolean
	return GamepassCache.GetOwnership(Player, GamepassId) == true
end

function GamepassCache.SetOwned(Player: Player, GamepassId: number, Value: boolean)
	if not Player.Parent then
		return
	end

	local Entity = FindPlayerEntity(Player)
	if not Entity then
		return
	end

	local Ownership = ECS.world:get(Entity, ECS.Components.GamepassOwnership) or {}
	Ownership[GamepassId] = Value
	ECS.world:set(Entity, ECS.Components.GamepassOwnership, Ownership)
end

return GamepassCache
