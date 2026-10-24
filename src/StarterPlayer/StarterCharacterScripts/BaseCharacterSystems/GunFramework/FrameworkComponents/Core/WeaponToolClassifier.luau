--!strict

--[[
	WeaponToolClassifier

	Guards the equip flow before Main clones models or binds controls. This module
	reads ACS_Settings safely and decides whether the tool type is allowed by the
	current feature flags.
]]

local WeaponDefinitionResolver = require(game:GetService("ReplicatedStorage").Shared.Game.Combat.Weapons.Resolver)

local WeaponToolClassifier = {}

export type WeaponSettings = {
	Type: string?,
}

export type FeatureFlags = {
	GunsEnabled: boolean,
	MeleeEnabled: boolean,
	GrenadesEnabled: boolean,
}

function WeaponToolClassifier.readSettings(tool: Instance?): WeaponSettings?
	-- A tool without ACS_Settings is just a normal Roblox tool and should be
	-- ignored by the gun framework.
	const settings = WeaponDefinitionResolver.getSettingsData(tool)
	if type(settings) ~= "table" then
		return nil
	end
	return settings :: WeaponSettings
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
