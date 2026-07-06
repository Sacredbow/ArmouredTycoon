--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local KOTHBanner = require(script.Parent.components.KOTHBanner)
local MainInterface = require(script.Parent.components.MainInterface)
local NPCConversationPanel = require(script.Parent.components.NPCConversationPanel)
local NukeCinematicPanel = require(script.Parent.components.NukeCinematicPanel)
local NotificationStack = require(script.Parent.components.NotificationStack)
local StoreProvider = require(script.Parent.store.StoreProvider)
local WeaponCrosshair = require(script.Parent.components.WeaponCrosshair)

local e = React.createElement

local function App()
	return e(StoreProvider, nil, {
		KOTHBanner = e(KOTHBanner),
		MainInterface = e(MainInterface),
		NPCConversation = e(NPCConversationPanel),
		NukeCinematic = e(NukeCinematicPanel),
		WeaponCrosshair = e(WeaponCrosshair),
		Notifications = e(NotificationStack),
	})
end

return App
