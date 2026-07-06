--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local InventoryShared = require(ReplicatedStorage.CharacterUtilities.Inventory.InventoryShared)

local HUD = require(game.StarterPlayer.StarterPlayerScripts.UI.components.HUD)
local InventoryPanel = require(game.StarterPlayer.StarterPlayerScripts.UI.components.Inventory.InventoryPanel)
local KOTHBanner = require(game.StarterPlayer.StarterPlayerScripts.UI.components.KOTHBanner)
local NPCConversationPanel = require(game.StarterPlayer.StarterPlayerScripts.UI.components.NPCConversationPanel)
local NotificationStack = require(game.StarterPlayer.StarterPlayerScripts.UI.components.NotificationStack)

local e = React.createElement

local inventorySnapshot = {
	isOpen = true,
	items = {
		{
			id = "app-preview-glock",
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
			id = "app-preview-m4",
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
	},
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

local previewStore = {
	DismissNotification = function() end,
	ChooseNPCConversationOption = function() end,
}

local story = {
	react = React,
	reactRoblox = ReactRoblox,
	summary = "Full mock mount of the active React HUD layer without joining the game.",
	story = function()
		return e("Frame", {
			BackgroundColor3 = Color3.fromRGB(18, 22, 29),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, {
			HUD = e(HUD, {
				stats = {
					Cash = 11000000,
					Emerald = 15,
					Kills = 32,
					Rebirths = 2,
				},
			}),
			KOTHBanner = e(KOTHBanner, {
				announcement = {
					id = 1,
					playerName = "Caleb",
					teamColor = Color3.fromRGB(80, 170, 255),
					minutes = nil,
					createdAt = os.clock(),
					duration = 999,
				},
			}),
			Inventory = e(InventoryPanel, {
				previewController = previewController,
				previewSnapshot = inventorySnapshot,
			}),
			NPCConversation = e(NPCConversationPanel, {
				conversation = {
					conversationId = "preview",
					npcName = "Civilian",
					npcLine = "Careful with that thing. People are nervous enough already.",
					turnCount = 1,
					maxTurns = 7,
					options = {
						{
							id = "calm",
							text = "\"Relax. I am just passing through.\"",
							tone = "calm",
						},
						{
							id = "ask",
							text = "\"Have you seen anything strange nearby?\"",
							tone = "curious",
						},
						{
							id = "leave",
							text = "End the conversation.",
							tone = "leave",
						},
					},
				},
				store = previewStore,
			}),
			Notifications = e(NotificationStack, {
				notifications = {
					{
						id = 1,
						kind = "info",
						message = "You can turn off user announcements in Settings.",
						createdAt = os.clock(),
						duration = 999,
					},
				},
				store = previewStore,
			}),
		})
	end,
}

return story
