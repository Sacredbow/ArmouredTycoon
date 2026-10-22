--!strict
--[[
	@class BanManager

	@desc
	Server-authoritative player banning for the experience.
	Uses Roblox's moderation API (Players:BanAsync) to permanently
	ban offenders, falling back to Kick() when the server lacks

	instead of the deprecated Player.UserId.
]]

--// Services

const Players = game:GetService("Players") 
const ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoggingEvent = require(ReplicatedStorage.Packages.signal).get("ServerLogging")

--// Public API

-- Bans a player from the experience. Returns true when the ban was
-- applied via BanAsync, false when it fell back to a kick.


local BanManager = {}


function BanManager.BanPlayer(player: Player, reason: string): boolean
	local success, Result = pcall(function()
		Players:BanAsync({
			UserIds = { player.UserId },
			Duration = -1,
			DisplayReason = reason,
			PrivateReason = `[Anti-Cheat] Banned {player.Name} (User {player.UserId}) for: {reason}`,
			ApplyToUniverse = true,
		})
	end)

	if not success then
		warn(`[BanManager] BanAsync failed for {player.Name}: {tostring(Result)}.`)
		LoggingEvent:Fire(player, `BanAsync failed for {player.Name}`, {
			error = tostring(Result),
			action = "BanAsync",
			reason = reason,
		})
		--player:Kick(reason)
		return false
	end

	warn(`[BanManager] Banned {player.Name} (User {player.UserId}) — {reason}`)
	return true
end


function BanManager.UnbanPlayer(player: Player): boolean
	local success, result = pcall(function()
		Players:UnbanAsync({
			UserIds = { player.UserId },
			ApplyToUniverse = true,
		})
	end)
	if not success then
		warn(`[BanManager] Unban failed for {player.Name}: {tostring(result)}`)
		LoggingEvent:Fire(player, `UnbanAsync failed for {player.Name}`, {
			error = tostring(result),
			action = "UnbanAsync",
		})
		return false
	end
	return success
end



return BanManager

