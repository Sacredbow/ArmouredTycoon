--!strict
-- Collision setup is a world boundary; reload gameplay is handled by ReloadSystem.
const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const Factory = require(ServerScriptService.Game.Tycoon.TycoonFactory)
const CollisionManager = require(ServerScriptService.Modules.CollisionManager)
const InteractionSystem = {}
function InteractionSystem.init(Entity: number): (() -> ())?
	const Hierarchy = Factory.GetHierarchy(Entity)
	const Stage1 = Hierarchy and Hierarchy.Stages and Hierarchy.Stages:FindFirstChild("Stage1")
	if not Stage1 then
		return nil
	end
	CollisionManager.Initialize()
	const Armour1 = Stage1:FindFirstChild("Armour1")
	const Armour2 = Stage1:FindFirstChild("Armour2")
	const AmmoArea = Stage1:FindFirstChild("AmmoArea")
	const Lakester = AmmoArea and AmmoArea:FindFirstChild("Lakester")
	for _, Character in
		{ Armour1 and Armour1:FindFirstChild("Character"), Armour2 and Armour2:FindFirstChild("Character"), Lakester }
	do
		if Character and Character:IsA("Model") then
			CollisionManager.SetNonCollidable(Character, false)
		end
	end
	return function() end
end

return InteractionSystem
