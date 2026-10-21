--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

local GamepassCache = {}
GamepassCache.__index = GamepassCache

function GamepassCache.new()
	local self = setmetatable({}, GamepassCache)
	self.GamepassIds = {} :: { [string]: number }
	return self
end

function GamepassCache:RegisterGamepass(gamepassId: number, key: string?)
	self.GamepassIds[key or tostring(gamepassId)] = gamepassId
end

function GamepassCache:Warm(player: Player)
	if not player.Parent then
		return
	end

	for _, gamepassId in self.GamepassIds do
		local success, message = pcall(function()
			self:Refresh(player, gamepassId)
		end)
		if not success then
			warn(`[GamepassCache] Ownership check failed for {player.Name}, pass {gamepassId}: {message}`)
		end
	end
end

function GamepassCache:Refresh(player: Player, gamepassId: number): boolean?
	if not player.Parent then
		return nil
	end

	local ownsPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	if not player.Parent then
		return nil
	end

	self:SetOwned(player, gamepassId, ownsPass)
	return ownsPass
end

function GamepassCache:GetOwnership(player: Player, gamepassId: number): boolean?
	return PlayerRuntimeState.GetGamepassOwnership(player, gamepassId)
end

function GamepassCache:Has(player: Player, gamepassId: number): boolean
	return self:GetOwnership(player, gamepassId) == true
end

function GamepassCache:SetOwned(player: Player, gamepassId: number, value: boolean)
	if player.Parent then
		PlayerRuntimeState.SetGamepassOwned(player, gamepassId, value)
	end
end

return GamepassCache
