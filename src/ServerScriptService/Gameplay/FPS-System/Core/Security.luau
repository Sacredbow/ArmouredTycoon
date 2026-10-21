--!strict
--[[
	@class FPSSecurity

	@desc
	Validates client combat requests: equipped weapon ownership and
	settings-table integrity. Replaces the legacy inline SKP_* security logic.
]]

--// Types

const Types = require(script.Parent.Types)

--// Public API

local LastRejectWarning: { [Player]: number } = setmetatable({}, { __mode = "k" })

function RejectRequest(player: Player, reason: string)
	local now = os.clock()
	if now - (LastRejectWarning[player] or -math.huge) >= 5 then
		LastRejectWarning[player] = now
		warn(`[FPS.Security] Rejected request from {player.Name}: {reason}`)
	end
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
		RejectRequest(player, "damage request with non-table modifiers")
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

function SecureSettings(player: Player, gun: Tool?, clientSettings: any?): any?
	if typeof(gun) ~= "Instance" or not gun:IsA("Tool") then
		RejectRequest(player, "damage request with invalid weapon")
		return nil
	end

	local character = player.Character
	if not character or gun.Parent ~= character then
		RejectRequest(player, "weapon is not equipped")
		return nil
	end

	local settingsModule = gun:FindFirstChild("ACS_Settings")
	if not settingsModule or not settingsModule:IsA("ModuleScript") then
		RejectRequest(player, "weapon is missing ACS_Settings")
		return nil
	end

	local success, serverSettings = pcall(require, settingsModule)
	if not success or type(serverSettings) ~= "table" then
		RejectRequest(player, "weapon settings could not be loaded")
		return nil
	end
	if clientSettings ~= nil and not CompareSettings(clientSettings, serverSettings) then
		RejectRequest(player, "weapon settings mismatch")
		return nil
	end

	return serverSettings
end

return {
	RejectRequest = RejectRequest,
	CompareSettings = CompareSettings,
	SecureSettings = SecureSettings,
	SecureModifiers = SecureModifiers,
}

