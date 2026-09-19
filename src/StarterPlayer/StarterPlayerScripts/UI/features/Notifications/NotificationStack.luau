--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local NotificationText = require(script.Parent.components.NotificationText)

local e = React.createElement

local function selectNotifications(snapshot)
	return snapshot.notifications
end

local function NotificationStack(props)
	props = props or {}

	local notifications = props.notifications
	if not notifications then
		local useGameStore = require(script.Parent.Parent.Parent.store.useGameStore)
		notifications = useGameStore(selectNotifications)
	end

	local children = {}

	for index, notification in ipairs(notifications) do
		children[tostring(notification.id)] = e(NotificationText, {
			notification = notification,
			offset = index - 1,
			store = props.store,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -142),
		Size = UDim2.fromOffset(520, 132),
	}, children)
end

return NotificationStack
