local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local CodesDataStore = DataStoreService:GetDataStore("RedeemedCodes")
local RedeemCode = ReplicatedStorage.Remotes.CodeServiceFunction

local CODES = {
	["R3L3ASE"] = function(player)
		player.leaderstats.Cash.Value += 5000
	end,
	["FR33MULTI"] = function(player)
		player:SetAttribute("Multiplier", true)
	end,
	["STARTER"] = function(player)
		player.leaderstats.Cash.Value += 10000
	end,
}

local CodeService = {}
CodeService.__index = CodeService

function CodeService.new()
	local self = setmetatable({}, CodeService)
	self.Redeemed = {}
	return self
end

function CodeService:_OnPlayerAdded(player)
	local success, data = pcall(function()
		return CodesDataStore:GetAsync("Player_" .. player.UserId)
	end)
	self.Redeemed[player] = (success and data) or {}
end

function CodeService:_OnPlayerRemoving(player)
	if self.Redeemed[player] then
		pcall(function()
			CodesDataStore:SetAsync("Player_" .. player.UserId, self.Redeemed[player])
		end)
		self.Redeemed[player] = nil
	end
end

function CodeService:_Redeem(player, code)
	code = string.upper(string.gsub(code, "%s+", ""))

	if code == "" then return false, "Empty Code" end
	if not CODES[code] then return false, "Invalid Code" end

	self.Redeemed[player] = self.Redeemed[player] or {}
	if self.Redeemed[player][code] then return false, "Already Redeemed" end

	self.Redeemed[player][code] = true
	CODES[code](player)

	pcall(function()
		CodesDataStore:SetAsync("Player_" .. player.UserId, self.Redeemed[player])
	end)

	return true, "Code Redeemed!"
end

function CodeService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:_OnPlayerAdded(player)
	end)

	RedeemCode.OnServerInvoke = function(player, code)
		return self:_Redeem(player, code)
	end
end

return CodeService