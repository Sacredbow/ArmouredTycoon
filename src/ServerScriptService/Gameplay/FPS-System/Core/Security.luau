--!strict
--[[
	@class FPSSecurity

	@desc
	Validates client combat requests: authorization tokens, weapon ownership,
	and settings-table integrity. Replaces the legacy inline SKP_* security logic.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const State = require(script.Parent.State)
const BanSignal = require(ServerScriptService.Signals.BanSignal)

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const Events = Engine:WaitForChild("Events")



--// Public API

function BanPlayer(player: Player, reason: string)
	warn(`[FPS.Security] {player.Name} — {reason}`)
	BanSignal:Fire(player, `You were permanently banned for {reason}`)
end

function IsAuthorized(player: Player, authToken: string): boolean
	-- Defensive guard: a non-string token (e.g. a spoofed table) would be
	-- coerced by string concatenation; reject it outright instead.
	if typeof(authToken) ~= "string" then
		return false
	end

	return authToken == State.AuthToken .. "-" .. player.UserId
end

-- Validates that both settings tables contain the three damage sub-arrays,
-- so the field-by-field compare below can never index a nil value.
local function HasDamageArrays(settings: any): boolean
	return type(settings) == "table"
		and type(settings.LimbDamage) == "table"
		and type(settings.TorsoDamage) == "table"
		and type(settings.HeadDamage) == "table"
end

function CompareSettings(clientSettings: any, serverSettings: any): boolean
	if not HasDamageArrays(clientSettings) or not HasDamageArrays(serverSettings) then
		return false
	end

	return clientSettings.gunName == serverSettings.gunName
		and clientSettings.Type == serverSettings.Type
		and clientSettings.ShootRate == serverSettings.ShootRate
		and clientSettings.Bullets == serverSettings.Bullets
		and clientSettings.LimbDamage[1] == serverSettings.LimbDamage[1]
		and clientSettings.LimbDamage[2] == serverSettings.LimbDamage[2]
		and clientSettings.TorsoDamage[1] == serverSettings.TorsoDamage[1]
		and clientSettings.TorsoDamage[2] == serverSettings.TorsoDamage[2]
		and clientSettings.HeadDamage[1] == serverSettings.HeadDamage[1]
		and clientSettings.HeadDamage[2] == serverSettings.HeadDamage[2]
end

function SecureModifiers(player: Player, modifiers: any): Types.ModifierSettings?
	if type(modifiers) ~= "table" then
		BanPlayer(player, "damage request with non-table modifiers")
		return nil
	end

	local damageMod = modifiers.DamageMod
	local minDamageMod = modifiers.minDamageMod

	-- All ACS attachments use DamageMod in [0.1, 1.0] (Suppressor=0.85, rest=1.0)
	-- Clamp to prevent exploiters from inflating damage multipliers
	if typeof(damageMod) ~= "number" or damageMod ~= damageMod then
		damageMod = 1
	else
		damageMod = math.clamp(damageMod, 0.1, 1.0)
	end

	if typeof(minDamageMod) ~= "number" or minDamageMod ~= minDamageMod then
		minDamageMod = 1
	else
		minDamageMod = math.clamp(minDamageMod, 0.1, 1.0)
	end

	return {
		DamageMod = damageMod,
		minDamageMod = minDamageMod,
	}
end

function SecureSettings(player: Player, gun: Tool?, clientSettings: any): boolean
	if not gun then
		BanPlayer(player, "damage request with missing weapon")
		return false
	end

	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local ownsWeapon = (character ~= nil and gun:IsDescendantOf(character))
		or (backpack ~= nil and gun:IsDescendantOf(backpack))
	if not ownsWeapon then
		BanPlayer(player, `weapon not owned: {gun:GetFullName()}`)
		return false
	end

	local settingsModule = gun:FindFirstChild("ACS_Settings")
	if not settingsModule or not settingsModule:IsA("ModuleScript") then
		BanPlayer(player, `weapon {gun.Name} is missing ACS_Settings`)
		return false
	end

	local serverSettings = require(settingsModule) :: ModuleScript
	if not CompareSettings(clientSettings, serverSettings) then
		BanPlayer(player, `weapon settings mismatch for {gun.Name}`)
		return false
	end

	return true
end

--// Event Wiring

function Init()
	local accessIdRemote = Events:FindFirstChild("AcessId") :: RemoteFunction?
	if not accessIdRemote then
		warn("[FPS.Security] AcessId remote not found; auth token requests will fail.")
		return
	end

	accessIdRemote.OnServerInvoke = function(player: Player, requestedUserId: number): string
		if typeof(requestedUserId) ~= "number" or player.UserId ~= requestedUserId then
			warn(`[FPS.Security] {player.Name} requested a token for user id {tostring(requestedUserId)}; returning empty auth token`)
			BanPlayer(player, "Configuring data using Exploits")
			return ""
		end

		return State.AuthToken
	end
end

return {
	BanPlayer = BanPlayer,
	IsAuthorized = IsAuthorized,
	CompareSettings = CompareSettings,
	SecureSettings = SecureSettings,
	SecureModifiers = SecureModifiers,
	Init = Init,
}

