--!strict
--[[
	@class FPSWeapons

	@desc
	Server-side weapon rigging and spawning for the ACS combat engine:
	attachment loading, R6 weapon model construction, stance ECS state,
	ammunition refill, and grenade spawning.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Packets = require(ReplicatedStorage.Network.Packets)
const State = require(script.Parent.State)

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const GunModels = Engine:WaitForChild("GunModels") :: any
const GrenadeModels = Engine:WaitForChild("GrenadeModels") :: any
const AttModels = Engine:WaitForChild("AttModels") :: any
const Mods = Engine:WaitForChild("Modules") :: any
const Ultil = require(Mods:WaitForChild("Utilities")) :: any
const ACS_Workspace = workspace:WaitForChild("ACS_WorkSpace") :: any

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
				Ultil.Weld(Handle, Key)
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
				Ultil.Weld(Handle, Key)
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
				Ultil.Weld(Handle, Key)
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
				Ultil.Weld(Handle, Key)
				Key.Anchored = false
				Key.CanCollide = false
			end
		end
	end
end

--// Internal Methods — Rig state

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

	Packets.packets.WeaponState.sendToAll({
		["type"] = "Equip",
		weaponName = Weapon.Name,
		stance = nil,
		lean = nil,
	})
end

local function ClearWeaponRigEntity(Player: Player)
	const Entity = State.WeaponRigEntities[Player]
	if Entity then
		ECS.deleteEntity(Entity)
		State.WeaponRigEntities[Player] = nil
	end

	Packets.packets.WeaponState.sendToAll({
		["type"] = "Unequip",
		weaponName = nil,
		stance = nil,
		lean = nil,
	})
end

--// Public API — Equip / Unequip

function Equip(Player: Player, Weapon: Tool, Mode: number, Settings: any, Anim: { [string]: CFrame })
	const Character = Player.Character
	if not Character then
		return
	end

	const Head = Character:FindFirstChild("Head")
	const Torso = Character:FindFirstChild("Torso")
	const LeftArm = Character:FindFirstChild("Left Arm")
	const RightArm = Character:FindFirstChild("Right Arm")
	if not Head or not Torso or not LeftArm or not RightArm then
		return
	end

	const RS = Torso:FindFirstChild("Right Shoulder")
	const LS = Torso:FindFirstChild("Left Shoulder")
	if not RS or not LS then
		return
	end

	--// EQUIP
	if Mode == 1 then
		const GunModel = GunModels:FindFirstChild(Weapon.Name)
		if not GunModel then
			warn(`[ACS] {Player.Name}: Couldn't load server-side weapon model`)
			return
		end

		local ServerGun = GunModel:Clone()
		ServerGun.Name = "S" .. Weapon.Name

		const ServerHandle = ServerGun:FindFirstChild("Handle")
		if not ServerHandle then
			warn(`[ACS] {Player.Name}: server gun model {Weapon.Name} is missing a Handle; aborting equip`)
			ServerGun:Destroy()
			return
		end

		const AnimBase = Instance.new("Part", Character)
		AnimBase.CanCollide = false
		AnimBase.Transparency = 1
		AnimBase.Anchored = false
		AnimBase.Name = "AnimBase"
		AnimBase.Size = Vector3.new(0.1, 0.1, 0.1)

		local AnimBaseW = Instance.new("Motor6D")
		AnimBaseW.Part0 = Head :: BasePart
		AnimBaseW.Part1 = AnimBase
		AnimBaseW.Parent = AnimBase
		AnimBaseW.Name = "AnimBaseW"

		local Raw = Instance.new("Motor6D")
		Raw.Name = "RAW"
		Raw.Part0 = RightArm :: BasePart
		Raw.Part1 = AnimBase
		Raw.Parent = AnimBase
		Raw.C0 = Anim.SV_RightArmPos
		RS.Enabled = false

		local Law = Instance.new("Motor6D")
		Law.Name = "LAW"
		Law.Part0 = LeftArm :: BasePart
		Law.Part1 = AnimBase
		Law.Parent = AnimBase
		Law.C0 = Anim.SV_LeftArmPos
		LS.Enabled = false

		ServerGun.Parent = Character
		LoadAttachment(ServerGun, Settings)

		const Nodes = ServerGun:FindFirstChild("Nodes")
		if Nodes then
			Nodes:Destroy()
		end

		for _, Descendant in ServerGun:GetDescendants() do
			if Descendant.Name == "SightMark" then
				Descendant:Destroy()
			end
		end

for _, Descendant in ServerGun:GetDescendants() do
			if not Descendant:IsA("BasePart") or Descendant.Name == "Handle" then
				continue
			end
			Ultil.WeldComplex(ServerHandle, Descendant, Descendant.Name)
		end

		local HandleMotor = Instance.new("Motor6D")
		HandleMotor.Name = "Handle"
		HandleMotor.Parent = ServerHandle
		HandleMotor.Part0 = RightArm :: BasePart
		HandleMotor.Part1 = ServerHandle
		HandleMotor.C1 = Anim.SV_GunPos:Inverse()

		for _, Descendant in ServerGun:GetDescendants() do
			if not Descendant:IsA("BasePart") then
				continue
			end
			Descendant.Anchored = false
			Descendant.CanCollide = false
		end

		SetWeaponRigEntity(Player, Character, Weapon, ServerGun, AnimBase)
		return
	end

	--// UNEQUIP
	if Mode == 2 then
		ClearWeaponRigEntity(Player)
		if Weapon and Character:FindFirstChild("S" .. Weapon.Name) then
			Character["S" .. Weapon.Name]:Destroy()
			const AnimBase = Character:FindFirstChild("AnimBase")
			if AnimBase then
				AnimBase:Destroy()
			end
		end

		RS.Enabled = true
		LS.Enabled = true
	end
end

--// Public API — Stance

function SetStanceState(Player: Player, Character: Model, Stance: number, Lean: number)
	local Entity = State.WeaponRigEntities[Player]
	if not Entity then
		Entity = ECS.createEntity({
			Name = `{Player.Name}:StanceState`,
			Character = Character,
		})
		State.WeaponRigEntities[Player] = Entity
	end

	ECS.set(Entity, "StanceState", {
		player = Player,
		character = Character,
		stance = Stance,
		lean = Lean,
		updatedAt = os.clock(),
	})

	Packets.packets.WeaponState.sendToAll({
		["type"] = "Stance",
		weaponName = nil,
		stance = Stance,
		lean = Lean,
	})
end

--// Public API — Grenades

function SpawnGrenade(
	Player: Player,
	GrenadeTool: Tool,
	WeaponSettings: any,
	SpawnCFrame: CFrame,
	ImpulseDirection: Vector3,
	ImpulsePower: number
)
	const Character = Player.Character
	if not Character then
		return
	end

const Template = GrenadeModels:FindFirstChild(WeaponSettings.gunName)
	if not Template then
		warn(`[ACS] Couldn't find {WeaponSettings.gunName} in grenade model folder`)
		return
	end

	-- Sanitise client-controlled numeric inputs (NaN / huge / negative).
	if typeof(ImpulsePower) ~= "number" or ImpulsePower ~= ImpulsePower
		or math.abs(ImpulsePower) == math.huge or ImpulsePower < 0 then
		warn(`[FPS.Weapons] {Player.Name} sent invalid grenade impulse power`)
		return
	end

	if typeof(ImpulseDirection) ~= "Vector3" or ImpulseDirection.Magnitude == 0 then
		warn(`[FPS.Weapons] {Player.Name} sent invalid grenade impulse direction`)
		return
	end

	const GrenadeModel = Template:Clone()
	if not GrenadeModel.PrimaryPart then
		return
	end

	const GrenadePrimaryPart = GrenadeModel.PrimaryPart :: any

	for _, CharacterPart in Character:GetChildren() do
		if not CharacterPart:IsA("BasePart") then
			continue
		end
		const NoCollisionConstraint = Instance.new("NoCollisionConstraint")
		NoCollisionConstraint.Parent = GrenadeModel
		NoCollisionConstraint.Part0 = GrenadePrimaryPart
		NoCollisionConstraint.Part1 = CharacterPart
	end

	const CreatorTag = Instance.new("ObjectValue")
	CreatorTag.Name = "creator"
	CreatorTag.Value = Player
	CreatorTag.Parent = GrenadePrimaryPart

	const ServerFolder = ACS_Workspace:FindFirstChild("Server")
	GrenadeModel.Parent = if ServerFolder then ServerFolder else workspace

	GrenadePrimaryPart.CFrame = SpawnCFrame
	GrenadePrimaryPart:ApplyImpulse(ImpulseDirection.Unit * ImpulsePower * GrenadePrimaryPart:GetMass())
	GrenadePrimaryPart:SetNetworkOwner(nil)

	const Damage = GrenadePrimaryPart:FindFirstChild("Damage")
	if Damage and Damage:IsA("BoolValue") then
		Damage.Value = false
	end

	if GrenadeTool.Parent then
		GrenadeTool:Destroy()
	end
end

--// Public API — Ammunition

function RefillAllMags(Player: Player, Weapon: Tool?)
	const Character = Player.Character
	if not Character then
		return
	end
	if not Weapon or not Weapon:IsA("Tool") or not Weapon:IsDescendantOf(Character) then
		warn(`[ACS] {Player.Name} weapon missing or not equipped for refill`)
		return
	end

	const ACS_Client = Weapon:FindFirstChild("ACS_Client")
	if not ACS_Client then
		warn(`[ACS] {Player.Name} weapon {Weapon.Name} is missing ACS_Client`)
		return
	end

	if ACS_Client:FindFirstChild("Stored") and ACS_Client:FindFirstChild("TotalMags") then
		ACS_Client.Stored.Value = ACS_Client.TotalMags.Value
	end
end

return {
	Equip = Equip,
	SetStanceState = SetStanceState,
	SpawnGrenade = SpawnGrenade,
	RefillAllMags = RefillAllMags,
}

