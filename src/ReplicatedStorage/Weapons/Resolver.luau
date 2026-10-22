--!strict

--[[
	Resolves immutable weapon definitions from ReplicatedStorage.Weapons.
	Legacy Tool children remain a fallback while authored assets migrate.

	Shared definition layout:
	ReplicatedStorage.Weapons.<WeaponId>.ACS_Settings
	ReplicatedStorage.Weapons.<WeaponId>.ACS_Animations
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const SharedWeapons = ReplicatedStorage:FindFirstChild("Weapons")

local WeaponDefinitionResolver = {}

local function getWeaponId(tool: Tool): string
	local configuredId = tool:GetAttribute("WeaponId")
	if typeof(configuredId) == "string" and configuredId ~= "" then
		return configuredId
	end

	return tool.Name
end

function WeaponDefinitionResolver.getModule(tool: Instance?, moduleName: string): ModuleScript?
	if not tool or not tool:IsA("Tool") then
		return nil
	end

	local weaponId = getWeaponId(tool)
	local sharedDefinition = SharedWeapons and SharedWeapons:FindFirstChild(weaponId)
	if sharedDefinition then
		local sharedModule = sharedDefinition:FindFirstChild(moduleName)
		if sharedModule and sharedModule:IsA("ModuleScript") then
			return sharedModule
		end
	end

	local legacyModule = tool:FindFirstChild(moduleName)
	if legacyModule and legacyModule:IsA("ModuleScript") then
		return legacyModule
	end

	return nil
end

function WeaponDefinitionResolver.getSettings(tool: Instance?): ModuleScript?
	return WeaponDefinitionResolver.getModule(tool, "ACS_Settings")
end

function WeaponDefinitionResolver.getAnimations(tool: Instance?): ModuleScript?
	return WeaponDefinitionResolver.getModule(tool, "ACS_Animations")
end

function WeaponDefinitionResolver.getId(tool: Instance?): string?
	if not tool or not tool:IsA("Tool") then
		return nil
	end

	return getWeaponId(tool)
end

return WeaponDefinitionResolver