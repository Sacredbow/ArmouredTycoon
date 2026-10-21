--!strict
-- ECS gun pickup system for a tycoon entity.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Factory = require(ServerScriptService.ECS.TycoonFactory)
local ValidatePromptRange = require(ServerScriptService.Classes.Tycoon.Utilities.ValidatePromptRange)
local Notify = require(ServerScriptService.Classes.Tycoon.Utilities.Notify)

local GunSystem = {}

function GunSystem.setup(entity: number): (() -> ())?
	local hierarchy = Factory.getHierarchy(entity)
	local gunModels = hierarchy and hierarchy.GunModels
	local guns = ServerStorage:FindFirstChild("Guns")
	if not gunModels or not guns then return nil end
	local connections: {RBXScriptConnection} = {}

	for _, gunModel in gunModels:GetChildren() do
		local requester = gunModel:FindFirstChild("Requester")
		local prompt = requester and requester:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then continue end
		table.insert(connections, prompt.Triggered:Connect(function(player: Player)
			local ownerData = ECS.world:get(entity, ECS.Components.Owner)
			if not ownerData or ownerData.player ~= player then
				Notify(player, "error", "Only the tycoon owner can collect this weapon.")
				return
			end
			if not ValidatePromptRange(player, prompt) then
				Notify(player, "info", "Move closer to collect this weapon.")
				return
			end
			local character = player.Character
			if player.Backpack:FindFirstChild(gunModel.Name)
				or player.StarterGear:FindFirstChild(gunModel.Name)
				or (character and character:FindFirstChild(gunModel.Name)) then
				Notify(player, "info", "You already have this weapon.")
				return
			end
			local template = guns:FindFirstChild(gunModel.Name)
			if not template then
				warn(`ServerStorage.Guns is missing the required {gunModel.Name} template`)
				return
			end
			template:Clone().Parent = player.Backpack
		end))
	end
	if #connections == 0 then return nil end
	return function()
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
	end
end

return GunSystem

