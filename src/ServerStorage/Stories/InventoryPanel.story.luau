--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local InventoryShared = require(ReplicatedStorage.CharacterUtilities.Inventory.InventoryShared)

local InventoryPanel = require(
	game.StarterPlayer.StarterPlayerScripts.UI.components.Inventory.InventoryPanel
)

local previewItems: { InventoryShared.InventoryItem } = {
	{
		id = "story-glock",
		name = "GLOCK19X (9MM)",
		category = "Weapon",
		rarity = "Rare",
		quantity = 1,
		slot = 1,
		accent = Color3.fromRGB(94, 174, 255),
		icon = nil,
		equipped = true,
		stats = {
			Damage = 28,
			["Fire Rate"] = 1760,
			Accuracy = 5,
			Capacity = 15,
		},
	},
	{
		id = "story-rifle",
		name = "M4A1",
		category = "Weapon",
		rarity = "Epic",
		quantity = 1,
		slot = 2,
		accent = Color3.fromRGB(187, 116, 255),
		icon = nil,
		equipped = false,
		stats = {
			Damage = 41,
			["Fire Rate"] = 720,
			Accuracy = 74,
			Capacity = 30,
		},
	},
	{
		id = "story-sniper",
		name = "SNIPER",
		category = "Weapon",
		rarity = "Legendary",
		quantity = 1,
		slot = 5,
		accent = Color3.fromRGB(255, 174, 74),
		icon = nil,
		equipped = false,
		stats = {
			Damage = 145,
			["Fire Rate"] = 90,
			Accuracy = 92,
			Capacity = 5,
		},
	},
}

local previewSnapshot = {
	isOpen = true,
	items = previewItems,
	selectedSlot = 1,
	maxSlots = InventoryShared.MAX_SLOTS,
}

local previewController = {
	ActivateSlot = function() end,
	SelectSlot = function() end,
	EquipSelected = function() end,
	RemoveSelected = function() end,
	UnequipSelected = function() end,
}

local story = {
	react = React,
	reactRoblox = ReactRoblox,
	summary = "Interactive Studio preview for the GTA-style inventory wheel.",
	story = function()
		return React.createElement(InventoryPanel, {
			previewController = previewController,
			previewSnapshot = previewSnapshot,
		})
	end,
}

return story
