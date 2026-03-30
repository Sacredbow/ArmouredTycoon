
local replicatedStorage = game:GetService("ReplicatedStorage")
local dataStoreService = game:GetService("DataStoreService")


local modulesFolder = replicatedStorage:WaitForChild("Modules")


local SettingsConfig = require(modulesFolder:WaitForChild("SettingsManager"):WaitForChild("SettingsConfig"))


local settingsDataStore = dataStoreService:GetDataStore(SettingsConfig.datastore_key) -- (YOU MUST ENABLE API SERVICES FOR THIS TOO WORK)


local remotesFolder = replicatedStorage:WaitForChild("Remotes")
local remotes_cache = {}
for _, child in pairs(remotesFolder:GetChildren()) do
	remotes_cache[child.Name] = child
end


function GetPlayerSettingsData(player)
	local success, data, err 
	local attempts = 10
	repeat
		success, data, err = pcall(function()
			return settingsDataStore:GetAsync(player.UserId)
		end)
		attempts -= 1
		wait()
	until success or attempts <= 0

	
	if not success then
		warn("Failed to fetch serialize settings data: " .. err, player.Name)	
		return success
	end

	
	if data == nil then
		
	else
		
	end
	return success, data, err
end

function ExportSettingsData(player, user_settings)

	local success, serializedData, err 
	local attempts = 10
	repeat
		success, serializedData, err = pcall(function()
			return settingsDataStore:SetAsync(player.UserId, user_settings)
		end)
		attempts -= 1
		wait()
	until success or attempts <= 0


	if not success then
		warn("Failed to serialize settings data: " .. err, player.Name)
	else
			
	end
	return success, serializedData, err
end


remotes_cache["GetSettingsData"].OnServerInvoke = function(player)
	return GetPlayerSettingsData(player)
end

remotes_cache["ImportSettingsFunction"].OnServerInvoke = function(player)

	local success, data, err = GetPlayerSettingsData(player)

	
	if not success then
		warn("Failed to decode settings data: " .. err, player.Name)
	else
		
	end
	return success, data
end

remotes_cache["ExportSettingsFunction"].OnServerInvoke = function(player, user_settings)
	return ExportSettingsData(player, user_settings)
end