--!strict
--[[
	@class RemoteController

	@desc
	Handles server-side settings data store operations: load, sanitize, cache, persist.
	Exposes the typed ByteNet settings query for the client settings UI.
]]

--// Services

const DataStoreService = game:GetService("DataStoreService")
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const SettingsConfig = require(ReplicatedStorage.Modules.SettingsManager.SettingsConfig)
const NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)
const Packets = require(ReplicatedStorage.Network.Packets)
const Observers = require(ReplicatedStorage.Packages.Observers)

--// Constants

const SETTINGS_DATASTORE = DataStoreService:GetDataStore(SettingsConfig.datastore_key)

--// State

local SettingsCache: { [Player]: { [string]: any } } = {}
type SaveScheduler = {
	Version: number,
	Pending: boolean,
}
local SaveSchedulers: { [Player]: SaveScheduler } = {}
--// Internal Utilities

local function GetSettingDefinitions(): { [string]: { class: string, min: number?, max: number?, choices: { string }? } }
	local Definitions: { [string]: { class: string, min: number?, max: number?, choices: { string }? } } = {}
	for _, Options in SettingsConfig.settings_options do
		for _, Option in Options do
			Definitions[Option.name] = Option.component
		end
	end
	return Definitions
end

local Definitions = GetSettingDefinitions()

local function SanitizeSettings(Player: Player?, Supplied: any): ({ [string]: any }, boolean)
	local Sanitized = table.clone(SettingsConfig.default_settings)
	local InvalidFields = 0

	if type(Supplied) ~= "table" then
		if Player then
			warn(`[Settings] {Player.Name} sent settings payload that was not a table`)
		end
		return Sanitized, false
	end

	for Name, Value in Supplied do
		local Definition = Definitions[Name]
		if not Definition then
			InvalidFields += 1
			continue
		end

		if Definition.class == "boolean" and typeof(Value) == "boolean" then
			Sanitized[Name] = Value
		elseif Definition.class == "range" and typeof(Value) == "number" and Value == Value and math.abs(Value) < math.huge then
			Sanitized[Name] = math.clamp(Value, Definition.min, Definition.max)
		elseif Definition.class == "choice" and typeof(Value) == "string" and table.find(Definition.choices, Value) then
			Sanitized[Name] = Value
		else
			InvalidFields += 1
		end
	end

	if Player and InvalidFields > 0 then
		warn(`[Settings] {Player.Name} sent {InvalidFields} unknown or malformed setting fields`)
	end

	return Sanitized, InvalidFields == 0
end

local function LoadSettings(Player: Player): (boolean, { [string]: any }, string?)
	if SettingsCache[Player] then
		return true, table.clone(SettingsCache[Player]), nil
	end

	local LastError: string?
	for Attempt = 1, 3 do
		local Success, Result = pcall(function()
			return SETTINGS_DATASTORE:GetAsync(tostring(Player.UserId))
		end)
		if Success then
			local Settings = SanitizeSettings(nil, Result or SettingsConfig.default_settings)
			SettingsCache[Player] = Settings
			return true, table.clone(Settings), nil
		end

		LastError = Result
		if Attempt < 3 then
			task.wait(0.5 * Attempt)
		end
	end

	warn(`[Settings] Failed to load settings for {Player.Name}: {tostring(LastError)}`)
	return false, table.clone(SettingsConfig.default_settings), tostring(LastError)
end

local function PersistSettings(Player: Player): boolean
	local Settings = SettingsCache[Player]
	if not Settings then
		return true
	end

	local Success, SaveError = pcall(function()
		SETTINGS_DATASTORE:SetAsync(tostring(Player.UserId), Settings)
	end)
	if not Success then
		warn(`[Settings] Failed to save settings for {Player.Name}: {tostring(SaveError)}`)
	end
	return Success
end

local function QueueSettingsSave(Player: Player, Supplied: any): boolean
	local Settings = SanitizeSettings(Player, Supplied)
	SettingsCache[Player] = Settings

	local Scheduler = SaveSchedulers[Player]
	if not Scheduler then
		Scheduler = {
			Version = 0,
			Pending = false,
		}
		SaveSchedulers[Player] = Scheduler
	end

	Scheduler.Version += 1
	if Scheduler.Pending then
		return true
	end

	Scheduler.Pending = true
	task.spawn(function()
		local LastObservedVersion = Scheduler.Version

		while Player.Parent do
			task.wait(3)
			if not Player.Parent then
				break
			end

			if Scheduler.Version ~= LastObservedVersion then
				LastObservedVersion = Scheduler.Version
				continue
			end

			PersistSettings(Player)
			if Scheduler.Version == LastObservedVersion then
				break
			end
			LastObservedVersion = Scheduler.Version
		end

		Scheduler.Pending = false
		if SaveSchedulers[Player] == Scheduler then
			SaveSchedulers[Player] = nil
		end
	end)

	return true
end
NetworkGuard.Query(Packets.queries.SettingsAction, "SettingsAction", {
	Rate = 2,
	Burst = 4,
	Validate = function(Request: any)
		return type(Request) == "table"
			and (Request.action == "Load" or Request.action == "Save")
			and (Request.payload == nil or (type(Request.payload) == "string" and #Request.payload <= 12000))
	end,
}, function(Request: any, Player: Player)
	if Request.action == "Load" then
		local Success, Data, LoadError = LoadSettings(Player)
		local Encoded: string? = nil
		if Success then
			local EncodeOk, Result = pcall(HttpService.JSONEncode, HttpService, Data)
			if EncodeOk then
				Encoded = Result
			else
				return { success = false, message = "Settings could not be encoded." }
			end
		end
		return { success = Success, message = LoadError or "", payload = Encoded }
	end

	if type(Request.payload) ~= "string" then
		return { success = false, message = "Settings payload is missing." }
	end
	local DecodeOk, Data = pcall(HttpService.JSONDecode, HttpService, Request.payload)
	if not DecodeOk or type(Data) ~= "table" then
		return { success = false, message = "Settings payload is invalid." }
	end
	local SaveOk = QueueSettingsSave(Player, Data)
	return { success = SaveOk, message = if SaveOk then "" else "Settings could not be queued." }
end)
--// Cleanup

Observers.observePlayer(function(Player: Player)
	return function()
		PersistSettings(Player)
		SettingsCache[Player] = nil
		SaveSchedulers[Player] = nil
	end
end)

game:BindToClose(function()
	for Player in SettingsCache do
		PersistSettings(Player)
	end
end)
