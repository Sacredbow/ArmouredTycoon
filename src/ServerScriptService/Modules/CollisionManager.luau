local PhysicsService = game:GetService("PhysicsService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.ECS)

local CollisionManager = {}

local function schedule(delay: number, callback: () -> (), name: string?)
        ECS.createEntity({
                Name = name or "CollisionManagerScheduledTask",
                ScheduledTask = {
                        delay = delay,
                        elapsed = 0,
                        callback = callback,
                },
        })
end

function CollisionManager.Initialize()
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:RegisterCollisionGroup("NPCs")
	PhysicsService:RegisterCollisionGroup("NonCollidableNPCs")
	PhysicsService:CollisionGroupSetCollidable("NPCs", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("NonCollidableNPCs", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("NonCollidableNPCs", "Default", false)
end

function CollisionManager.NonCollidable(character, collideWithWorld)
	if collideWithWorld == nil then
		collideWithWorld = true
	end
	local groupName = collideWithWorld and "NPCs" or "NonCollidableNPCs"
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
        end
        character.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("BasePart") then
                        schedule(0.1, function()
                                if descendant.Parent then
                                        descendant.CollisionGroup = groupName
                                end
                        end, "CollisionManager:GroupDescendant")
                end
        end)
end

function CollisionManager.NegativeCollision(character)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
        end
        character.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("BasePart") then
                        schedule(0.1, function()
                                if descendant.Parent then
                                        descendant.CanCollide = false
                                end
                        end, "CollisionManager:DisableDescendant")
                end
        end)
end

function CollisionManager.SetupPlayerCharacter(character)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
        end
        character.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("BasePart") then
                        schedule(0.1, function()
                                if descendant.Parent then
                                        descendant.CollisionGroup = "Players"
                                end
                        end, "CollisionManager:PlayerDescendant")
                end
        end)
end

function CollisionManager.PartCollison(character, partNames)
	local nameSet = {}
	for _, name in ipairs(partNames) do
		nameSet[name] = true
	end
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") and nameSet[part.Name] then
			part.CanCollide = false
		end
	end
end

function CollisionManager.ResetCollision(character)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Default"
			part.CanCollide = true
		end
	end
end

return CollisionManager
