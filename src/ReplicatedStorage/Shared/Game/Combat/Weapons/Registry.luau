--!strict

--[[
	Shared weapon definition registry. Every weapon owns its authored settings
	and animation modules under ReplicatedStorage.Shared.Game.Combat.Weapons.<WeaponId>.
]]

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const WeaponsFolder = ReplicatedStorage:WaitForChild("Weapons")

export type WeaponDefinition = {
	Id: string,
	Folder: Folder,
	SettingsModule: ModuleScript,
	AnimationsModule: ModuleScript,
}

local Definitions: {[string]: WeaponDefinition} = {}
local Aliases: {[string]: string} = {}

for _, Child in WeaponsFolder:GetChildren() do
	if not Child:IsA("Folder") then
		continue
	end

	const SettingsModule = Child:FindFirstChild("ACS_Settings")
	const AnimationsModule = Child:FindFirstChild("ACS_Animations")
	if not SettingsModule or not SettingsModule:IsA("ModuleScript")
		or not AnimationsModule or not AnimationsModule:IsA("ModuleScript") then
		warn("[Weapons] " .. Child.Name .. " is missing ACS_Settings or ACS_Animations")
		continue
	end

	const Definition: WeaponDefinition = {
		Id = Child.Name,
		Folder = Child,
		SettingsModule = SettingsModule,
		AnimationsModule = AnimationsModule,
	}
	Definitions[Definition.Id] = Definition
	Aliases[string.lower(Definition.Id)] = Definition.Id
end

local WeaponRegistry = {}

function WeaponRegistry.get(WeaponId: string?): WeaponDefinition?
	if typeof(WeaponId) ~= "string" or WeaponId == "" then
		return nil
	end

	const Exact = Definitions[WeaponId]
	if Exact then
		return Exact
	end

	const CanonicalId = Aliases[string.lower(WeaponId)]
	return CanonicalId and Definitions[CanonicalId] or nil
end

function WeaponRegistry.getAll(): {[string]: WeaponDefinition}
	return Definitions
end

return WeaponRegistry
