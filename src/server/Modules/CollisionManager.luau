local PhysicsService = game:GetService("PhysicsService")
local CollisionManager = {}

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
			task.wait(0.1)
			descendant.CollisionGroup = groupName
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
			task.wait(0.1)
			descendant.CanCollide = false
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
			task.wait(0.1)
			descendant.CollisionGroup = "Players"
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