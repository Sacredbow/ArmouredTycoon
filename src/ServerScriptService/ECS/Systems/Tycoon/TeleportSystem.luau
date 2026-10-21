--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ECS = require(ReplicatedStorage.ECS)
local Factory = require(ServerScriptService.ECS.TycoonFactory)
local Packets = require(ReplicatedStorage.Network.Packets)
local ValidatePromptRange = require(ServerScriptService.Classes.Tycoon.Utilities.ValidatePromptRange)
local Notify = require(ServerScriptService.Classes.Tycoon.Utilities.Notify)

local TeleportSystem = {}

function TeleportSystem.setup(entity: number, playerService: any): (() -> ())?
	local hierarchy = Factory.getHierarchy(entity)
	local tycoonModel = Factory.getModel(entity)
	if not hierarchy or not hierarchy.Stages or not tycoonModel then return nil end
	local connections: {RBXScriptConnection} = {}
	local cancelled = false

	for _, teleportModel in hierarchy.Stages:GetDescendants() do
		if not teleportModel:HasTag("Teleporters") or not teleportModel:IsA("Model") then continue end
		local teleportPart = teleportModel:FindFirstChild("Teleport")
		local prompt = teleportPart and teleportPart:FindFirstChild("TeleportPrompt")
		local spawnPoint = teleportModel:FindFirstChild("SpawnPoint")
		if not teleportPart or not teleportPart:IsA("BasePart") then
			warn(`Could not find Teleport part for {teleportModel:GetFullName()}`)
			continue
		end
		if not prompt or not prompt:IsA("ProximityPrompt") then
			warn(`Could not find TeleportPrompt for {teleportPart:GetFullName()}`)
			continue
		end
		if not spawnPoint or not spawnPoint:IsA("BasePart") then
			warn(`Could not find SpawnPoint for {teleportModel:GetFullName()}`)
			continue
		end

		table.insert(connections, prompt.Triggered:Connect(function(player: Player)
			local ownerData = ECS.world:get(entity, ECS.Components.Owner)
			if not ownerData or ownerData.player ~= player then
				Notify(player, "error", "Only the tycoon owner can use this teleporter.")
				return
			end
			if not ValidatePromptRange(player, prompt) then
				Notify(player, "info", "Move closer to use the teleporter.")
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not root or not root:IsA("BasePart") then return end
			local yaw = select(2, root.CFrame:ToEulerAnglesYXZ())
			local groundPosition = teleportPart.Position - Vector3.new(0, teleportPart.Size.Y / 2, 0)
			playerService:AllowServerTeleport(player, 0.5)
			character:PivotTo(CFrame.new(groundPosition) * CFrame.Angles(0, yaw, 0))
			Packets.packets.Notification.sendTo({["type"] = "info", message = "Teleporting...", RequiresFade = true}, player)
			task.delay(1.5, function()
				if cancelled or not player.Parent or not character.Parent then return end
				local currentOwner = ECS.world:get(entity, ECS.Components.Owner)
				if not currentOwner or currentOwner.player ~= player then return end
				playerService:AllowServerTeleport(player, 0.4)
				character:PivotTo(spawnPoint.CFrame)
			end)
		end))
	end
	if #connections == 0 then return nil end
	return function()
		cancelled = true
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
	end
end

return TeleportSystem

