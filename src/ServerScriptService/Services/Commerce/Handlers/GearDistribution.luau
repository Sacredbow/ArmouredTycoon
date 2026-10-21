--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

local GearDistribution = {}

type PlayerServiceLike = {
	SetX2: (player: Player, value: boolean) -> (),
}

local function hasTool(player: Player, toolName: string): boolean
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local starterGear = player:FindFirstChild("StarterGear")

	if backpack and backpack:FindFirstChild(toolName) then
		return true
	end

	if character and character:FindFirstChild(toolName) then
		return true
	end

	if starterGear and starterGear:FindFirstChild(toolName) then
		return true
	end

	return false
end

function GearDistribution.GiveShield(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	if character:FindFirstChild("Shield") then
		return true
	end

	local leftArm = character:FindFirstChild("Left Arm")
	if not leftArm or not leftArm:IsA("BasePart") then
		return false
	end

	local shieldTemplate = ReplicatedStorage:FindFirstChild("Assets")
		and (ReplicatedStorage.Assets :: Folder):FindFirstChild("CharacterItems")
		and ReplicatedStorage.Assets.CharacterItems:FindFirstChild("Shield")
	if not shieldTemplate or not shieldTemplate:IsA("Model") or not shieldTemplate.PrimaryPart then
		return false
	end

	local shield = shieldTemplate:Clone()
	local primaryPart = shield.PrimaryPart
	if not primaryPart then
		shield:Destroy()
		return false
	end
	local weld = Instance.new("Weld")
	weld.Part0 = leftArm
	weld.Part1 = primaryPart
	weld.C0 = CFrame.new(-0.1, 0, 0) * CFrame.Angles(math.rad(90), 0, math.rad(-90))
	weld.Parent = primaryPart
	shield.Parent = character
	return true
end
function GearDistribution.GiveHK416(player: Player)
	if hasTool(player, "HK416") then
		return
	end

	local guns = ServerStorage:FindFirstChild("Guns")
	if not guns then
		return
	end

	local hk = guns:FindFirstChild("HK416")
	if hk and hk:IsA("Tool") then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			hk:Clone().Parent = backpack
		end
	end
end

function GearDistribution.GiveClothes(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso or not torso:IsA("BasePart") then
		return
	end

	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	if not Assets then
		return
	end

	local characterItems = (Assets :: Folder):FindFirstChild("CharacterItems")
	if not characterItems then
		return
	end

	local armourFolder = (characterItems :: Folder):FindFirstChild("Armour")
	local swatVest = armourFolder and armourFolder:FindFirstChild("SWAT_Vest")
	if swatVest and swatVest:IsA("Model") and swatVest.PrimaryPart then
		local vest = swatVest:Clone()
		vest.Parent = character
		vest:PivotTo(torso.CFrame * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0))

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = vest.PrimaryPart :: BasePart
		weld.Parent = vest.PrimaryPart
	end

	humanoid.MaxHealth = 300
	humanoid.Health = 300
	PlayerRuntimeState.SetArmourEquipped(player, true)

	local description = humanoid:GetAppliedDescription()
	description.Shirt = 6433605120
	description.Pants = 8883038978
	humanoid:ApplyDescriptionAsync(description)
end

function GearDistribution.GiveRainbowCarpet(player: Player)
	if hasTool(player, "RainbowCarpet") then
		return
	end

	local item = ServerStorage:FindFirstChild("GamepassItems")
		and (ServerStorage.GamepassItems :: Folder):FindFirstChild("RainbowCarpet")
	if not item or not item:IsA("Tool") then
		return
	end

	local starterGear = player:FindFirstChild("StarterGear")
	local backpack = player:FindFirstChild("Backpack")
	if starterGear then
		item:Clone().Parent = starterGear
	end
	if backpack then
		item:Clone().Parent = backpack
	end
end

function GearDistribution.GiveRayGun(player: Player)
	if hasTool(player, "Raygun") then
		return
	end

	local item = ServerStorage:FindFirstChild("GamepassItems")
		and (ServerStorage.GamepassItems :: Folder):FindFirstChild("Raygun")
	if not item or not item:IsA("Tool") then
		return
	end

	local starterGear = player:FindFirstChild("StarterGear")
	local backpack = player:FindFirstChild("Backpack")
	if starterGear then
		item:Clone().Parent = starterGear
	end
	if backpack then
		item:Clone().Parent = backpack
	end
end

function GearDistribution.ApplyGamepassReward(player: Player, gamepassId: number, playerService: PlayerServiceLike)
	if gamepassId == 1568782544 then
		GearDistribution.GiveRainbowCarpet(player)
	elseif gamepassId == 1793083522 then
		GearDistribution.GiveRayGun(player)
	elseif gamepassId == 1568972351 then
		playerService:SetX2(player, true)
	end
end

return GearDistribution
