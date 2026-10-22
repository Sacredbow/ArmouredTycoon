--!strict

local InventoryFeature = require(game:GetService("ReplicatedStorage").CharacterUtilities.Inventory.FeatureConfig)
if not InventoryFeature.Enabled then
	return
end

local InventoryController = require(script.Parent.Controller)

InventoryController.get():Start()
