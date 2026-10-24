--!strict
--[[
	@class RarityModule

	@desc
	Weighted random box selection for rarity-based loot boxes.
	Returns a box model from ReplicatedStorage.Assets.Workspace.Boxes
	based on configured rarity weights.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
--// Constants

const BoxFolder = ReplicatedStorage.Assets.Workspace.Boxes
const Boxes: { [string]: Instance } = {
	Common = BoxFolder.Common,
	Rare = BoxFolder.Rare,
	Legendary = BoxFolder.Legendary,
	Mythical = BoxFolder.Mythical,
	Divine = BoxFolder.Divine,
}

const RarityNames: { string } = { "Common", "Rare", "Legendary", "Mythical", "Divine" }
const RarityWeights: { number } = { 49, 30, 16, 4, 1 }
const RandomGenerator = Random.new()
--// Module

local RarityModule = {}

--// Public API

function RarityModule:SpawnRandomBox(): Instance?
	const RandomNumber = RandomGenerator:NextInteger(1, 100)
	local Counter = 0

	for Index = 1, #RarityNames do
		Counter += RarityWeights[Index]
		if Counter >= RandomNumber then
			return Boxes[RarityNames[Index]]
		end
	end

	return Boxes.Common
end

return RarityModule
