--!strict
--[[
	@class CollisionManager

	@desc
	Manages collision groups for NPC models, player characters, and armour pickups.
	Provides idempotent group registration and re-runnable collision assignment.

	All group assignments use DescendantAdded watchers so newly-added parts
	(crucial for NPCs that respawn or change models on rebirth) automatically
	get the correct collision group.
]]

--// Services

const PhysicsService = game:GetService("PhysicsService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ECS = require(ReplicatedStorage.ECS)

--// Constants

const SCHEDULE_DELAY = 0.1

--// Types

export type CollisionManager = {
	Initialize: () -> (),
	SetNonCollidable: (Character: Model, CollideWithWorld: boolean?) -> (),
	SetNegativeCollision: (Character: Model) -> (),
	SetupPlayerCharacter: (Character: Model) -> (),
	SetPartCollision: (Character: Model, PartNames: { string }) -> (),
	ResetAll: (Character: Model) -> ()
}

--// Collision Group Registration (idempotent)

local RegisteredGroups: { [string]: boolean } = {}

local function RegisterCollisionGroup(Name: string)
	if RegisteredGroups[Name] then
		return
	end

	local ExistingGroups = PhysicsService:GetRegisteredCollisionGroups()
	for _, Group in ExistingGroups do
		if Group.name == Name then
			RegisteredGroups[Name] = true
			return
		end
	end

	PhysicsService:RegisterCollisionGroup(Name)
	RegisteredGroups[Name] = true
end

--// Module

local CollisionManager: CollisionManager = {}

--// Internal Utilities

local function Schedule(Delay: number, Callback: () -> (), Name: string?)
	ECS.createEntity({
		Name = Name or "CollisionManagerScheduledTask",
		ScheduledTask = {
			delay = Delay,
			elapsed = 0,
			callback = Callback
		}
	})
end

local function WatchDescendants(Character: Model, GroupName: string)
	Character.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("BasePart") then
			Schedule(SCHEDULE_DELAY, function()
				if Descendant.Parent then
					Descendant.CollisionGroup = GroupName
				end
			end, "CollisionManager:GroupDescendant")
		end
	end)
end

--// Public API

function CollisionManager.Initialize()
	RegisterCollisionGroup("Players")
	RegisterCollisionGroup("NPCs")
	RegisterCollisionGroup("NonCollidableNPCs")
	PhysicsService:CollisionGroupSetCollidable("NPCs", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("NonCollidableNPCs", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("NonCollidableNPCs", "Default", false)
end

function CollisionManager.SetNonCollidable(Character: Model, CollideWithWorld: boolean?)
	local GroupName = if CollideWithWorld ~= false then "NPCs" else "NonCollidableNPCs"

	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CollisionGroup = GroupName
		end
	end

	WatchDescendants(Character, GroupName)
end

function CollisionManager.SetNegativeCollision(Character: Model)
	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CanCollide = false
		end
	end

	Character.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("BasePart") then
			Schedule(SCHEDULE_DELAY, function()
				if Descendant.Parent then
					Descendant.CanCollide = false
				end
			end, "CollisionManager:DisableDescendant")
		end
	end)
end

function CollisionManager.SetupPlayerCharacter(Character: Model)
	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CollisionGroup = "Players"
		end
	end

	Character.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("BasePart") then
			Schedule(SCHEDULE_DELAY, function()
				if Descendant.Parent then
					Descendant.CollisionGroup = "Players"
				end
			end, "CollisionManager:PlayerDescendant")
		end
	end)
end

function CollisionManager.SetPartCollision(Character: Model, PartNames: { string })
	local NameSet: { [string]: boolean } = {}
	for _, Name in PartNames do
		NameSet[Name] = true
	end

	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") and NameSet[Part.Name] then
			Part.CanCollide = false
		end
	end
end

function CollisionManager.ResetAll(Character: Model)
	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CollisionGroup = "Default"
			Part.CanCollide = true
		end
	end
end

return CollisionManager
