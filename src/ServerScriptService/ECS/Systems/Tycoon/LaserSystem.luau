--!strict
-- ECS laser hazard for a tycoon entity.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Factory = require(ServerScriptService.ECS.TycoonFactory)

local LaserSystem = {}

function LaserSystem.setup(entity: number): (() -> ())?
	local hierarchy = Factory.getHierarchy(entity)
	local stage4 = hierarchy and hierarchy.Stages and hierarchy.Stages:FindFirstChild("Stage4")
	local lasers = stage4 and stage4:FindFirstChild("Lasers")
	if not lasers then return nil end
	local connections: {RBXScriptConnection} = {}
	for _, laser in lasers:GetChildren() do
		if not laser:IsA("BasePart") then continue end
		table.insert(connections, laser.Touched:Connect(function(hit: Instance)
			if laser.Transparency ~= 0 then return end
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then return end
			local ownerData = ECS.world:get(entity, ECS.Components.Owner)
			if ownerData and ownerData.player == player then return end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				 humanoid:TakeDamage(math.huge)
			end
		end))
	end
	if #connections == 0 then return nil end
	return function()
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
	end
end

return LaserSystem

