--!strict

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerStorage = game:GetService("ServerStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)


local function SetArmourEquipped(Player: Player, Value: boolean)
	for Entity, PlayerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if PlayerRef == Player then
			ECS.world:set(Entity, ECS.Components.ArmourEquipped, Value)
			return
		end
	end
end

const GearDistribution = {}

local function HasTool(Player: Player, ToolName: string): boolean
	const Backpack = Player:FindFirstChild("Backpack")
	const Character = Player.Character
	const StarterGear = Player:FindFirstChild("StarterGear")

	if Backpack and Backpack:FindFirstChild(ToolName) then
		return true
	end

	if Character and Character:FindFirstChild(ToolName) then
		return true
	end

	if StarterGear and StarterGear:FindFirstChild(ToolName) then
		return true
	end

	return false
end

function GearDistribution.GiveShield(Player: Player): boolean
	const Character = Player.Character
	if not Character then
		return false
	end

	if Character:FindFirstChild("Shield") then
		SetArmourEquipped(Player, true)
		return true
	end

	const LeftArm = Character:FindFirstChild("Left Arm")
	if not LeftArm or not LeftArm:IsA("BasePart") then
		return false
	end

	const Assets = ReplicatedStorage:FindFirstChild("Assets")
	const CharacterItems = Assets and Assets:IsA("Folder") and Assets:FindFirstChild("CharacterItems")
	const ShieldTemplate = CharacterItems and CharacterItems:IsA("Folder") and CharacterItems:FindFirstChild("Shield")
	if not ShieldTemplate or not ShieldTemplate:IsA("Model") or not ShieldTemplate.PrimaryPart then
		return false
	end

	const Shield = ShieldTemplate:Clone()
	const PrimaryPart = Shield.PrimaryPart
	if not PrimaryPart then
		Shield:Destroy()
		return false
	end

	const Weld = Instance.new("Weld")
	Weld.Part0 = LeftArm
	Weld.Part1 = PrimaryPart
	Weld.C0 = CFrame.new(-0.1, 0, 0) * CFrame.Angles(math.rad(90), 0, math.rad(-90))
	Weld.Parent = PrimaryPart
	Shield.Parent = Character
	SetArmourEquipped(Player, true)
	return true
end

function GearDistribution.GiveHK416(Player: Player)
	if HasTool(Player, "HK416") then
		return
	end

	const Guns = ServerStorage:FindFirstChild("Guns")
	if not Guns or not Guns:IsA("Folder") then
		return
	end

	const HK416 = Guns:FindFirstChild("HK416")
	if HK416 and HK416:IsA("Tool") then
		const Backpack = Player:FindFirstChild("Backpack")
		if Backpack then
			HK416:Clone().Parent = Backpack
		end
	end
end

function GearDistribution.GiveClothes(Player: Player)
	const Character = Player.Character
	if not Character then
		return
	end

	const Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	const Torso = Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
	if not Torso or not Torso:IsA("BasePart") then
		return
	end

	const Assets = ReplicatedStorage:FindFirstChild("Assets")
	if not Assets or not Assets:IsA("Folder") then
		return
	end

	const CharacterItems = Assets:FindFirstChild("CharacterItems")
	if not CharacterItems or not CharacterItems:IsA("Folder") then
		return
	end

	const ArmourFolder = CharacterItems:FindFirstChild("Armour")
	const SwatVest = ArmourFolder and ArmourFolder:IsA("Folder") and ArmourFolder:FindFirstChild("SWAT_Vest")
	if SwatVest and SwatVest:IsA("Model") and SwatVest.PrimaryPart then
		const Vest = SwatVest:Clone()
		Vest.Parent = Character
		Vest:PivotTo(Torso.CFrame * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0))

		const Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Torso
		Weld.Part1 = Vest.PrimaryPart :: BasePart
		Weld.Parent = Vest.PrimaryPart
	end

	Humanoid.MaxHealth = 300
	Humanoid.Health = 300
	SetArmourEquipped(Player, true)

	const Description = Humanoid:GetAppliedDescription()
	Description.Shirt = 6433605120
	Description.Pants = 8883038978
	Humanoid:ApplyDescriptionAsync(Description)
end

function GearDistribution.GiveRainbowCarpet(Player: Player)
	if HasTool(Player, "RainbowCarpet") then
		return
	end

	const GamepassItems = ServerStorage:FindFirstChild("GamepassItems")
	const Item = GamepassItems and GamepassItems:IsA("Folder") and GamepassItems:FindFirstChild("RainbowCarpet")
	if not Item or not Item:IsA("Tool") then
		return
	end

	const StarterGear = Player:FindFirstChild("StarterGear")
	const Backpack = Player:FindFirstChild("Backpack")
	if StarterGear then
		Item:Clone().Parent = StarterGear
	end
	if Backpack then
		Item:Clone().Parent = Backpack
	end
end

function GearDistribution.GiveRayGun(Player: Player)
	if HasTool(Player, "Raygun") then
		return
	end

	const GamepassItems = ServerStorage:FindFirstChild("GamepassItems")
	const Item = GamepassItems and GamepassItems:IsA("Folder") and GamepassItems:FindFirstChild("Raygun")
	if not Item or not Item:IsA("Tool") then
		return
	end

	const StarterGear = Player:FindFirstChild("StarterGear")
	const Backpack = Player:FindFirstChild("Backpack")
	if StarterGear then
		Item:Clone().Parent = StarterGear
	end
	if Backpack then
		Item:Clone().Parent = Backpack
	end
end

return GearDistribution