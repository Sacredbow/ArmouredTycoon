--!strict

local INVENTORY_ENABLED = false
if not INVENTORY_ENABLED then
	return
end

local InventoryController = require(script.Parent.Controller)

InventoryController.get():Start()
