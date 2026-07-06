local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)

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
	if not success then
		Diagnostics.report("CodeService", `Failed to load redeemed codes for {player.Name}: {tostring(data)}`)
	end
	self.Redeemed[player] = (success and data) or {}
end

function CodeService:_OnPlayerRemoving(player)
	if self.Redeemed[player] then
		local success, saveError = pcall(function()
			CodesDataStore:SetAsync("Player_" .. player.UserId, self.Redeemed[player])
		end)
		if not success then
			Diagnostics.report("CodeService", `Failed to save redeemed codes for {player.Name}: {tostring(saveError)}`)
		end
		self.Redeemed[player] = nil
	end
end

function CodeService:_Redeem(player, code)
	if typeof(code) ~= "string" or #code > 64 then
		Diagnostics.reject(player, "CodeService", "Code was not a string or exceeded 64 characters")
		return false, "Invalid Code"
	end
	local compactCode = string.gsub(code, "%s+", "")
	code = string.upper(compactCode)

	if code == "" then return false, "Empty Code" end
	if not CODES[code] then return false, "Invalid Code" end

	self.Redeemed[player] = self.Redeemed[player] or {}
	if self.Redeemed[player][code] then return false, "Already Redeemed" end

	self.Redeemed[player][code] = true
	CODES[code](player)

	local success, saveError = pcall(function()
		CodesDataStore:SetAsync("Player_" .. player.UserId, self.Redeemed[player])
	end)
	if not success then
		Diagnostics.report("CodeService", `Immediate save failed for {player.Name}: {tostring(saveError)}`)
	end

	return true, "Code Redeemed!"
end

function CodeService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:_OnPlayerAdded(player)
	end)

	RedeemCode.OnServerInvoke = function(player, code)
		local success, accepted, response = xpcall(function()
			return self:_Redeem(player, code)
		end, debug.traceback)
		if not success then
			Diagnostics.report("CodeService", `Redemption failed internally for {player.Name}:\n{accepted}`)
			return false, "Code service unavailable."
		end
		return accepted, response
	end
end

return CodeService
