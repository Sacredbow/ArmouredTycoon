-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local CharacterStats = ReplicatedStorage.Remotes.CharacterStats

-- local SynchronizeCash = CharacterStats.SynchronizeCash
-- local SynchronizeEmerald = CharacterStats.SynchronizeEmerald
-- local SynchronizeKills = CharacterStats.SynchronizeKills

local ProfileManager = {}

-- Store profiles from the Profile Store.

ProfileManager.Profiles = {}
-- Adds Cash to the catorgized player.
function ProfileManager.AddCash(player, amount)
	local profile = ProfileManager.Profiles[player]
	if not profile then return end
	profile.Data.Cash += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Cash.Value = profile.Data.Cash
		
	end
end
-- Adds Emerald to the catorgized player.
function ProfileManager.AddEmerald(player : Player, amount : number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Emerald += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Emerald.Value = profile.Data.Emerald
        
	end
end


-- Adds Kills to the catorgorized player.
function ProfileManager.AddKills(player : Player, amount : number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Kills += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Kills.Value = profile.Data.Kills
    
	end
end

-- Adds Rebirths to the catorgorized player.
function ProfileManager.AddRebirths(player : Player, amount : number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	profile.Data.Rebirths += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Rebirths.Value = profile.Data.Rebirths

	end
end


return ProfileManager