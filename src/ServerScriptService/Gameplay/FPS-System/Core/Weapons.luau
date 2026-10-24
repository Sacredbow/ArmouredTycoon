--!strict
--[[
	@class FPSWeapons

	@desc
	Server-side weapon rigging for the ACS combat engine: attachment loading, R6 weapon model construction, stance ECS state, and ammunition refill.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const State = require(script.Parent.State)

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const GunModels = Engine:WaitForChild("GunModels") :: any
const AttModels = Engine:WaitForChild("AttModels") :: any
const AttModules = Engine:WaitForChild("AttModules") :: any
const Mods = Engine:WaitForChild("Modules") :: any
const Utilities = require(Mods:WaitForChild("Utilities")) :: any

--// Internal Methods — Attachments

-- Clones an attachment template by name, guarding against missing/empty
-- names and templates that aren't in AttModels (client-controlled data).
local function CloneAttachment(Weapon: any, Name: string): any
	if typeof(Name) ~= "string" or Name == "" then
		return nil
	end

	const Template = AttModels:FindFirstChild(Name)
	if not Template then
		warn(`[FPS.Weapons] Attachment template "{Name}" not found in AttModels`)
		return nil
	end

	const Cloned = Template:Clone()
	Cloned.Parent = Weapon
	return Cloned
end

local function LoadAttachment(Weapon: any, WeaponData: any)
	if not Weapon or not WeaponData or not Weapon:FindFirstChild("Nodes") then
		return
	end

	const Handle = Weapon:FindFirstChild("Handle")
	if not Handle then
		warn(`[FPS.Weapons] Weapon {Weapon.Name} is missing a Handle; skipping attachments`)
		return
	end

	--// Sight attachment
	if Weapon.Nodes:FindFirstChild("Sight") and type(WeaponData.SightAtt) == "string" then
		const SightAtt = CloneAttachment(Weapon, WeaponData.SightAtt)
		if SightAtt then
			SightAtt:PivotTo(Weapon.Nodes.Sight.CFrame)

			for _, Key in Weapon:GetChildren() do
				if not Key:IsA("BasePart") or Key.Name ~= "IS" then
					continue
				end
				Key.Transparency = 1
			end

			for _, Key in SightAtt:GetChildren() do
				if Key.Name == "SightMark" or Key.Name == "Main" then
					Key:Destroy()
					continue
				end
				if not Key:IsA("BasePart") then
					continue
				end
				Utilities.Weld(Handle, Key)
				Key.Anchored = false
				Key.CanCollide = false
			end
		end
	end

	--// Barrel attachment
	if Weapon.Nodes:FindFirstChild("Barrel") and type(WeaponData.BarrelAtt) == "string" then
		const BarrelAtt = CloneAttachment(Weapon, WeaponData.BarrelAtt)
		if BarrelAtt then
			BarrelAtt:PivotTo(Weapon.Nodes.Barrel.CFrame)

			local BarrelPos = BarrelAtt:FindFirstChild("BarrelPos")
			local Muzzle = Handle:FindFirstChild("Muzzle")
			if BarrelPos and Muzzle and Muzzle:IsA("BasePart") then
				Muzzle.WorldCFrame = BarrelPos.CFrame
			end

			for _, Key in BarrelAtt:GetChildren() do
				if not Key:IsA("BasePart") then
					continue
				end
				Utilities.Weld(Handle, Key)
				Key.Anchored = false
				Key.CanCollide = false
			end
		end
	end

	--// Under-barrel attachment
	if Weapon.Nodes:FindFirstChild("UnderBarrel") and type(WeaponData.UnderBarrelAtt) == "string" then
		const UnderBarrelAtt = CloneAttachment(Weapon, WeaponData.UnderBarrelAtt)
		if UnderBarrelAtt then
			UnderBarrelAtt:PivotTo(Weapon.Nodes.UnderBarrel.CFrame)

			for _, Key in UnderBarrelAtt:GetChildren() do
				if not Key:IsA("BasePart") then
					continue
				end
				Utilities.Weld(Handle, Key)
				Key.Anchored = false
				Key.CanCollide = false
			end
		end
	end

	--// Other attachment
	if Weapon.Nodes:FindFirstChild("Other") and type(WeaponData.OtherAtt) == "string" then
		const OtherAtt = CloneAttachment(Weapon, WeaponData.OtherAtt)
		if OtherAtt then
			OtherAtt:PivotTo(Weapon.Nodes.Other.CFrame)

			for _, Key in OtherAtt:GetChildren() do
				if not Key:IsA("BasePart") then
					continue
				end
				Utilities.Weld(Handle, Key)
				Key.Anchored = false
				Key.CanCollide = false
			end
		end
	end
end

--// Internal Methods — Rig state

local function ReadCombatState(WeaponData: any): any
	local state = {
		DamageMod = 1,
		minDamageMod = 1,
		suppressor = false,
		flashHider = false,
	}
	if type(WeaponData) ~= "table" then
		return state
	end

	local function readMultiplier(value: any): number
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return 1
		end
		return math.clamp(value, 0.1, 1)
	end
	for _, attachmentName in { WeaponData.SightAtt, WeaponData.BarrelAtt, WeaponData.UnderBarrelAtt, WeaponData.OtherAtt } do
		if type(attachmentName) ~= "string" or attachmentName == "" then
			continue
		end
		local module = AttModules:FindFirstChild(attachmentName)
		if not module or not module:IsA("ModuleScript") then
			continue
		end
		local success, attachmentData = pcall(require, module)
		if not success or type(attachmentData) ~= "table" then
			continue
		end
		state.DamageMod *= readMultiplier(attachmentData.DamageMod)
		state.minDamageMod *= readMultiplier(attachmentData.minDamageMod)
		state.suppressor = state.suppressor or attachmentData.IsSuppressor == true
		state.flashHider = state.flashHider or attachmentData.IsFlashHider == true
	end
	return state
end
type ActiveRig = { tool: Tool, character: Model, model: Model, animBase: BasePart, combatState: any }
local ActiveRigs: { [Player]: ActiveRig } = setmetatable({}, { __mode = "k" })

local function SetWeaponRigEntity(Player: Player, Character: Model, Weapon: Tool, ServerGun: Model, AnimBase: BasePart)
	const OldEntity = State.WeaponRigEntities[Player]
	if OldEntity then
		ECS.deleteEntity(OldEntity)
	end

	State.WeaponRigEntities[Player] = ECS.createEntity({
		Name = `{Player.Name}:{Weapon.Name}:WeaponRig`,
		Model = ServerGun,
		Character = Character,
		WeaponRig = {
			player = Player,
			character = Character,
			tool = Weapon,
			model = ServerGun,
			animBase = AnimBase,
			equippedAt = os.clock(),
		},
	})

end

local function ClearWeaponRigEntity(Player: Player)
	const Entity = State.WeaponRigEntities[Player]
	if Entity then
		ECS.deleteEntity(Entity)
		State.WeaponRigEntities[Player] = nil
	end

end

return {
	Equip = Equip,
	ClearEquippedRig = ClearEquippedRig,
	SetStanceState = SetStanceState,
	GetCombatState = GetCombatState,
}

