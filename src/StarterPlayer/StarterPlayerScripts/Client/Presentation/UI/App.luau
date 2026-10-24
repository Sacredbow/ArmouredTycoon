--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local KOTHBanner = require(script.Parent.features.HUD.components.KOTHBanner)
local MenuRouter = require(script.Parent.features.Menu.MenuRouter)
local NPCConversationView = require(script.Parent.features.Dialogue.NPCConversationView)
local NukeCinematicView = require(script.Parent.features.Cinematics.NukeCinematicView)
local NotificationStack = require(script.Parent.features.Notifications.NotificationStack)
local StoreProvider = require(script.Parent.store.StoreProvider)
local WeaponCrosshair = require(script.Parent.features.HUD.components.WeaponCrosshair)
local InventoryView = require(script.Parent.features.Inventory.InventoryView)
local InventoryFeature = require(ReplicatedStorage.Shared.Game.Inventory.FeatureConfig)

local e = React.createElement

local function App()
	return e(StoreProvider, nil, {
		KOTHBanner = e(KOTHBanner),
		MenuRouter = e(MenuRouter),
		NPCConversation = e(NPCConversationView),
		NukeCinematic = e(NukeCinematicView),
		WeaponCrosshair = e(WeaponCrosshair),
		Notifications = e(NotificationStack),
		Inventory = if InventoryFeature.Enabled then e(InventoryView) else nil,
	})
end

return App
