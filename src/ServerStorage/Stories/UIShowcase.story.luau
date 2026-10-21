--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local NotificationText = require(game.StarterPlayer.StarterPlayerScripts.UI.features.Notifications.components.NotificationText)

local e = React.createElement
local previewStore = {
	DismissNotification = function() end,
}

local story = {
	react = React,
	reactRoblox = ReactRoblox,
	summary = "Studio preview for reusable HUD and notification components.",
	story = function()
		return e("Frame", {
			BackgroundColor3 = Color3.fromRGB(10, 13, 18),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, {
			Notifications = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 1, -80),
				Size = UDim2.fromOffset(560, 112),
			}, {
				Info = e(NotificationText, {
					offset = 0,
					store = previewStore,
					notification = {
						id = 1,
						kind = "info",
						message = "You can turn off user announcements in Settings.",
						createdAt = os.clock(),
						duration = 999,
					},
				}),
				Success = e(NotificationText, {
					offset = 1,
					store = previewStore,
					notification = {
						id = 2,
						kind = "success",
						message = "Tycoon purchase complete.",
						createdAt = os.clock(),
						duration = 999,
					},
				}),
				Warning = e(NotificationText, {
					offset = 2,
					store = previewStore,
					notification = {
						id = 3,
						kind = "warning",
						message = "King of the Hill is contested.",
						createdAt = os.clock(),
						duration = 999,
					},
				}),
			}),
		})
	end,
}

return story
