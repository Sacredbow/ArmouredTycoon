--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
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
	local registrationKey = key or tostring(gamepassId)
	self.GamepassIds[registrationKey] = gamepassId
end

function GamepassCache:Warm(player: Player)
	if not player.Parent then
		return
	end

	for _, gamepassId in pairs(self.GamepassIds) do
		self:Refresh(player, gamepassId)
	end
end

function GamepassCache:Refresh(player: Player, gamepassId: number): boolean
	if not player.Parent then
		return false
	end

	local ownsPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	self:SetOwned(player, gamepassId, ownsPass)
	return ownsPass
end

function GamepassCache:Has(player: Player, gamepassId: number): boolean
	return PlayerRuntimeState.HasGamepassOwned(player, gamepassId)
end

function GamepassCache:SetOwned(player: Player, gamepassId: number, value: boolean)
	PlayerRuntimeState.SetGamepassOwned(player, gamepassId, value)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerRuntimeState.Clear(player)
end)

return GamepassCache
