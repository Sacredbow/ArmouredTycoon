--!strict
-- ECS interaction setup for collision groups and the Lakester reload prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Factory = require(ServerScriptService.ECS.TycoonFactory)
local CollisionManager = require(ServerScriptService.Modules.CollisionManager)
local ReloadConfig = require(ServerScriptService.Classes.Tycoon.Systems.Interaction.ReloadConfig)
local ValidatePromptRange = require(ServerScriptService.Classes.Tycoon.Utilities.ValidatePromptRange)
local Notify = require(ServerScriptService.Classes.Tycoon.Utilities.Notify)

local InteractionSystem = {}

function InteractionSystem.setup(entity: number): (() -> ())?
	local hierarchy = Factory.getHierarchy(entity)
	local stage1 = hierarchy and hierarchy.Stages and hierarchy.Stages:FindFirstChild("Stage1")
	if not stage1 then return nil end
	CollisionManager.Initialize()

	local armour1 = stage1:FindFirstChild("Armour1")
	local armour2 = stage1:FindFirstChild("Armour2")
	local ammoArea = stage1:FindFirstChild("AmmoArea")
	local lakester = ammoArea and ammoArea:FindFirstChild("Lakester")
	if lakester then
		local armour1Character = armour1 and armour1:FindFirstChild("Character")
		local armour2Character = armour2 and armour2:FindFirstChild("Character")
		if armour1Character and armour1Character:IsA("Model") then CollisionManager.SetNonCollidable(armour1Character, false) end
		if armour2Character and armour2Character:IsA("Model") then CollisionManager.SetNonCollidable(armour2Character, false) end
		if lakester:IsA("Model") then CollisionManager.SetNonCollidable(lakester, false) end
	end

	local connections: {RBXScriptConnection} = {}
	local requester = lakester and lakester:FindFirstChild("Requester")
	local prompt = requester and requester:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		table.insert(connections, prompt.Triggered:Connect(function(player: Player)
			local ownerData = ECS.world:get(entity, ECS.Components.Owner)
			if not ownerData or ownerData.player ~= player then
				Notify(player, "error", "Only the tycoon owner can reload here.")
				return
			end
			if not ValidatePromptRange(player, prompt) then
				Notify(player, "info", "Move closer to reload your weapon.")
				return
			end
			ReloadConfig.onPromptTriggered(player)
		end))
	end
	if #connections == 0 and not lakester then return nil end
	return function()
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
	end
end

return InteractionSystem

