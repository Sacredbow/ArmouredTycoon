--!strict

--[[
	WeaponToolClassifier

	Guards the equip flow before Main clones models or binds controls. This module
	reads ACS_Settings safely and decides whether the tool type is allowed by the
	current feature flags.
]]

local WeaponDefinitionResolver = require(game:GetService("ReplicatedStorage").Weapons.Resolver)

local WeaponToolClassifier = {}

export type WeaponSettings = {
	Type: string?,
}

export type FeatureFlags = {
	GunsEnabled: boolean,
	MeleeEnabled: boolean,
	GrenadesEnabled: boolean,
}

local function requireModule<T>(moduleScript: ModuleScript): T?
	-- Tool configs are authored per weapon, so failed requires are treated as
	-- non-equipable instead of crashing the character script.
	local ok, result = pcall(require, moduleScript)
	if not ok or type(result) ~= "table" then
		return nil
	end

	return result :: T
end

function WeaponToolClassifier.readSettings(tool: Instance?): WeaponSettings?
	-- A tool without ACS_Settings is just a normal Roblox tool and should be
	-- ignored by the gun framework.
	local settings = WeaponDefinitionResolver.getSettings(tool)
	if not settings or not settings:IsA("ModuleScript") then
		return nil
	end

	local weaponSettings: WeaponSettings? = requireModule(settings)
	return weaponSettings
end

function WeaponToolClassifier.canEquip(settings: WeaponSettings?, flags: FeatureFlags): boolean
	-- Feature flags let us pause old ACS systems while keeping the data/modules
	-- around for a later rewrite.
	if not settings then
		return false
	end

	if settings.Type == "Gun" then
		return flags.GunsEnabled
	end

	if settings.Type == "Melee" then
		return flags.MeleeEnabled
	end

	if settings.Type == "Grenade" then
		return flags.GrenadesEnabled
	end

	return false
end

return WeaponToolClassifier
