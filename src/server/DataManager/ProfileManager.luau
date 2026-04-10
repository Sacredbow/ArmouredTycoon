-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local CharacterStats = ReplicatedStorage.Remotes.CharacterStats

-- local SynchronizeCash = CharacterStats.SynchronizeCash
-- local SynchronizeEmerald = CharacterStats.SynchronizeEmerald
-- local SynchronizeKills = CharacterStats.SynchronizeKills

local ProfileManager = {}

-- Store profiles from the Profile Store.

ProfileManager.Profiles = {}

local function getStatisticValue(player: Player, folderName: string, statName: string): IntValue?
	local folder = player:FindFirstChild(folderName)
	if not folder then
		return nil
	end

	local stat = folder:FindFirstChild(statName)
	if stat and stat:IsA("IntValue") then
		return stat
	end

	return nil
end

-- Adds Cash to the catorgized player.
function ProfileManager.AddCash(player: Player, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then return end
	profile.Data.Cash += amount
	local cashStat = getStatisticValue(player, "leaderstats", "Cash")
	if cashStat then
		cashStat.Value = profile.Data.Cash
	end
end

function ProfileManager.SetCash(player: Player, amount: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Cash = amount
	local cashStat = getStatisticValue(player, "leaderstats", "Cash")
	if cashStat then
		cashStat.Value = amount
	end
end

-- Adds Emerald to the catorgized player.
function ProfileManager.AddEmerald(player : Player, amount : number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Emerald += amount
	local emeraldStat = getStatisticValue(player, "leaderstats", "Emerald")
	if emeraldStat then
		emeraldStat.Value = profile.Data.Emerald
	end
end


-- Adds Kills to the catorgorized player.
function ProfileManager.AddKills(player : Player, amount : number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Kills += amount
	local killsStat = getStatisticValue(player, "leaderstats", "Kills")
	if killsStat then
		killsStat.Value = profile.Data.Kills
	end
end

-- Adds Rebirths to the catorgorized player.
function ProfileManager.AddRebirths(player : Player, amount : number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Rebirths += amount
	local rebirthsStat = getStatisticValue(player, "Statistics", "Rebirths")
	if rebirthsStat then
		rebirthsStat.Value = profile.Data.Rebirths
	end
end


return ProfileManager
