local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SettingsConfig = require(ReplicatedStorage.Modules.SettingsManager.SettingsConfig)
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)

local settingsDataStore = DataStoreService:GetDataStore(SettingsConfig.datastore_key)
local remotesFolder = Diagnostics.requireValue(ReplicatedStorage:FindFirstChild("Remotes"), "SettingsService", "ReplicatedStorage.Remotes is required")
local settingsCache = {}
local saveVersions = {}

local function settingDefinitions()
	local definitions = {}
	for _, options in SettingsConfig.settings_options do
		for _, option in options do
			definitions[option.name] = option.component
		end
	end
	return definitions
end

local definitions = settingDefinitions()

local function sanitizeSettings(player: Player?, supplied)
	local sanitized = table.clone(SettingsConfig.default_settings)
	local invalidFields = 0

	if type(supplied) ~= "table" then
		if player then
			Diagnostics.reject(player, "Settings", "Settings payload was not a table")
		end
		return sanitized, false
	end

	for name, value in supplied do
		local definition = definitions[name]
		if not definition then
			invalidFields += 1
			continue
		end

		if definition.class == "boolean" and typeof(value) == "boolean" then
			sanitized[name] = value
		elseif definition.class == "range" and typeof(value) == "number" and value == value and math.abs(value) < math.huge then
			sanitized[name] = math.clamp(value, definition.min, definition.max)
		elseif definition.class == "choice" and typeof(value) == "string" and table.find(definition.choices, value) then
			sanitized[name] = value
		else
			invalidFields += 1
		end
	end

	if player and invalidFields > 0 then
		Diagnostics.reject(player, "Settings", `Ignored {invalidFields} unknown or malformed setting fields`)
	end

	return sanitized, invalidFields == 0
end

local function loadSettings(player: Player)
	if settingsCache[player] then
		return true, table.clone(settingsCache[player]), nil
	end

	local lastError
	for attempt = 1, 3 do
		local success, result = pcall(function()
			return settingsDataStore:GetAsync(tostring(player.UserId))
		end)
		if success then
			local settings = sanitizeSettings(nil, result or SettingsConfig.default_settings)
			settingsCache[player] = settings
			return true, table.clone(settings), nil
		end

		lastError = result
		if attempt < 3 then
			task.wait(0.5 * attempt)
		end
	end

	Diagnostics.report("SettingsService", `Failed to load settings for {player.Name}: {tostring(lastError)}`)
	return false, table.clone(SettingsConfig.default_settings), tostring(lastError)
end

local function persistSettings(player: Player): boolean
	local settings = settingsCache[player]
	if not settings then
		return true
	end

	local success, saveError = pcall(function()
		settingsDataStore:SetAsync(tostring(player.UserId), settings)
	end)
	if not success then
		Diagnostics.reportThrottled(
			"SettingsService",
			`tostring(player.UserId)`,
			`Failed to save settings for {player.Name}: {tostring(saveError)}`,
			15
		)
	end
	return success
end

local function queueSettingsSave(player: Player, supplied)
	local settings = sanitizeSettings(player, supplied)
	settingsCache[player] = settings

	local version = (saveVersions[player] or 0) + 1
	saveVersions[player] = version
	task.delay(3, function()
		if saveVersions[player] ~= version then
			return
		end
		persistSettings(player)
	end)

	return true
end

local function requireRemoteFunction(name: string): RemoteFunction
	local remote = Diagnostics.requireValue(remotesFolder:FindFirstChild(name), "SettingsService", `Remotes.{name} is required`)
	Diagnostics.invariant(remote:IsA("RemoteFunction"), "SettingsService", `Remotes.{name} must be a RemoteFunction`)
	return remote :: RemoteFunction
end

requireRemoteFunction("GetSettingsData").OnServerInvoke = function(player: Player)
	return loadSettings(player)
end

requireRemoteFunction("ImportSettingsFunction").OnServerInvoke = function(player: Player)
	local success, data, loadError = loadSettings(player)
	return success, data, loadError
end

requireRemoteFunction("ExportSettingsFunction").OnServerInvoke = function(player: Player, supplied)
	return queueSettingsSave(player, supplied)
end

Players.PlayerRemoving:Connect(function(player)
	persistSettings(player)
	settingsCache[player] = nil
	saveVersions[player] = nil
end)

game:BindToClose(function()
	for player in settingsCache do
		persistSettings(player)
	end
end)
