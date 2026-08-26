--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local Theme = require(script.Parent.Parent.theme.Theme)
local useSpringBinding = require(script.Parent.Parent.hooks.useSpringBinding)

local e = React.createElement

local TONE_COLORS = {
	error = Color3.fromRGB(255, 78, 78),
	warning = Color3.fromRGB(255, 205, 80),
	success = Color3.fromRGB(96, 230, 140),
	tutorial = Color3.fromRGB(116, 221, 255),
	info = Color3.fromRGB(235, 242, 255),
}

local function getToneColor(type: string): Color3
	return TONE_COLORS[type] or TONE_COLORS.info
end

local function NotificationText(props)
	local notification = props.notification
	local offset = props.offset or 0
	local store = props.store
	if not store then
		local GameStore = require(script.Parent.Parent.store.GameStore)
		store = GameStore.get()
	end

	local visible, setVisible = React.useState(true)
	local progress = useSpringBinding(if visible then 1 else 0, 15, 0)

	React.useEffect(function()
		local cancelled = false
		if notification.duration <= 0 then
			return function()
				cancelled = true
			end
		end

		task.delay(notification.duration, function()
			if cancelled then
				return
			end

			setVisible(false)
			task.delay(0.24, function()
				if not cancelled and store and store.DismissNotification then
					store:DismissNotification(notification.id)
				end
			end)
		end)

		return function()
			cancelled = true
		end
	end, { notification.id })

	local color = getToneColor(notification.type)
	local yOffset = -offset * 30

	return e("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		GroupTransparency = progress:map(function(value)
			return 1 - value
		end),
		Position = progress:map(function(value)
			return UDim2.new(0.5, 0, 1, yOffset + (1 - value) * 10)
		end),
		Size = UDim2.fromOffset(520, 30),
	}, {
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Size = UDim2.fromScale(1, 1),
			Text = notification.message,
			TextColor3 = color,
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(5, 7, 10),
			TextStrokeTransparency = 0.18,
			TextWrapped = false,
		}, {
			SizeLimit = e("UITextSizeConstraint", {
				MaxTextSize = 23,
				MinTextSize = 12,
			}),
		}),
	})
end

return NotificationText
