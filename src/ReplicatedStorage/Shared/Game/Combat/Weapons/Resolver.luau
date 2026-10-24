--!strict

--[[
	Shared weapon resolver. Tools use a canonical WeaponId attribute; tool names
	remain a compatibility fallback. Required module values are cached by module.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const WeaponRegistry = require(ReplicatedStorage.Shared.Game.Combat.Weapons.Registry)

type Definition = WeaponRegistry.WeaponDefinition

local LoadedValues: {[ModuleScript]: any} = {}
local FailedModules: {[ModuleScript]: boolean} = {}
local WeaponDefinitionResolver = {}

local function readConfiguredId(Tool: Tool): string
	for _, AttributeName in {"WeaponId", "WeaponID"} do
		const Value = Tool:GetAttribute(AttributeName)
		if typeof(Value) == "string" and Value ~= "" then
			return Value
		end
	end
	return Tool.Name
end

local function loadModule(ModuleScript: ModuleScript): any?
	const CachedValue = LoadedValues[ModuleScript]
	if CachedValue ~= nil then
		return CachedValue
	end
	if FailedModules[ModuleScript] then
		return nil
	end

	const Success, Value = pcall(require, ModuleScript)
	if not Success or type(Value) ~= "table" then
		FailedModules[ModuleScript] = true
		warn("[Weapons] Failed to load " .. ModuleScript:GetFullName())
		return nil
	end

	LoadedValues[ModuleScript] = Value
	return Value
end

function WeaponDefinitionResolver.getDefinition(Tool: Instance?): Definition?
	if not Tool or not Tool:IsA("Tool") then
		return nil
	end
	return WeaponRegistry.get(readConfiguredId(Tool))
end

function WeaponDefinitionResolver.getModule(Tool: Instance?, ModuleName: string): ModuleScript?
	if not Tool or not Tool:IsA("Tool") then
		return nil
	end

	const Definition = WeaponDefinitionResolver.getDefinition(Tool)
	if Definition then
		if ModuleName == "ACS_Settings" then
			return Definition.SettingsModule
		elseif ModuleName == "ACS_Animations" then
			return Definition.AnimationsModule
		end
	end

	-- Compatibility for a Tool that has not been migrated into Weapons yet.
	const LegacyModule = Tool:FindFirstChild(ModuleName)
	return LegacyModule and LegacyModule:IsA("ModuleScript") and LegacyModule or nil
end

function WeaponDefinitionResolver.getSettings(Tool: Instance?): ModuleScript?
	return WeaponDefinitionResolver.getModule(Tool, "ACS_Settings")
end

function WeaponDefinitionResolver.getAnimations(Tool: Instance?): ModuleScript?
	return WeaponDefinitionResolver.getModule(Tool, "ACS_Animations")
end

function WeaponDefinitionResolver.getSettingsData(Tool: Instance?): {[any]: any}?
	const ModuleScript = WeaponDefinitionResolver.getSettings(Tool)
	return ModuleScript and loadModule(ModuleScript) or nil
end

function WeaponDefinitionResolver.getAnimationsData(Tool: Instance?): {[any]: any}?
	const ModuleScript = WeaponDefinitionResolver.getAnimations(Tool)
	return ModuleScript and loadModule(ModuleScript) or nil
end

function WeaponDefinitionResolver.getId(Tool: Instance?): string?
	if not Tool or not Tool:IsA("Tool") then
		return nil
	end

	const ConfiguredId = readConfiguredId(Tool)
	const Definition = WeaponRegistry.get(ConfiguredId)
	return Definition and Definition.Id or ConfiguredId
end

function WeaponDefinitionResolver.assignId(Tool: Instance?): string?
	if not Tool or not Tool:IsA("Tool") then
		return nil
	end

	const CanonicalId = WeaponDefinitionResolver.getId(Tool)
	if CanonicalId and WeaponRegistry.get(CanonicalId) then
		Tool:SetAttribute("WeaponId", CanonicalId)
		return CanonicalId
	end
	return nil
end

return WeaponDefinitionResolver
