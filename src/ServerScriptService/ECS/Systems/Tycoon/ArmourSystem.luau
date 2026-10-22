--!strict
-- ECS armour pickup system for a tycoon entity.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Factory = require(ServerScriptService.ECS.TycoonFactory)
local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

local ArmourSystem = {}
local VESTS = {
	Armour1 = {health = 50, template = "Armour1"},
	Armour2 = {health = 120, template = "Armour2"},
}

local function equipVest(character: Model, template: Model, healthBonus: number)
	local vest = template:Clone()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth += healthBonus
		humanoid.Health += healthBonus
	end
	local torso = (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso"))
	if torso and torso:IsA("BasePart") and vest.PrimaryPart then
		vest.Parent = character
		vest:PivotTo(torso.CFrame * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = vest.PrimaryPart
		weld.Parent = vest.PrimaryPart
	end
end

function ArmourSystem.setup(entity: number): (() -> ())?
	local hierarchy = Factory.getHierarchy(entity)
	local stage1 = hierarchy and hierarchy.Stages and hierarchy.Stages:FindFirstChild("Stage1")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local characterItems = assets and assets:FindFirstChild("CharacterItems")
	local armourAssets = characterItems and characterItems:FindFirstChild("Armour")
	if not stage1 or not armourAssets then return nil end

	local connections: {RBXScriptConnection} = {}
	for name, config in VESTS do
		local pickup = stage1:FindFirstChild(name)
		local part = pickup and pickup:FindFirstChild("Part")
		local template = armourAssets:FindFirstChild(config.template)
		if not part or not part:IsA("BasePart") or not template or not template:IsA("Model") then continue end
		table.insert(connections, part.Touched:Connect(function(hit: Instance)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			local ownerData = ECS.world:get(entity, ECS.Components.Owner)
			if not player or not ownerData or ownerData.player ~= player then return end
			if part.Transparency ~= 0 or PlayerRuntimeState.HasArmourEquipped(player) then return end
			local character = player.Character
			if not character then return end
			PlayerRuntimeState.SetArmourEquipped(player, true)
			equipVest(character, template, config.health)
		end))
	end
	if #connections == 0 then return nil end
	return function()
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
	end
end

return ArmourSystem

