--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local Theme = require(script.Parent.Parent.theme.Theme)
local Format = require(script.Parent.Parent.utils.Format)
local useAnimatedNumber = require(script.Parent.Parent.hooks.useAnimatedNumber)

local e = React.createElement

local function StatPill(props)
	local animatedValue = useAnimatedNumber(props.value or 0, 14)
	local accent: Color3 = props.accent

	return e("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(164, 48),
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),

		Stroke = e("UIStroke", {
			Color = accent,
			Thickness = 1,
			Transparency = 0.42,
		}),

		Gradient = e("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, accent:Lerp(Color3.new(1, 1, 1), 0.08)),
				ColorSequenceKeypoint.new(0.38, Theme.Colors.PanelRaised),
				ColorSequenceKeypoint.new(1, Theme.Colors.Panel),
			}),
			Rotation = 18,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.72),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
		}),

		Accent = e("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(0, 3, 1, -16),
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),

		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Body,
			Position = UDim2.fromOffset(14, 7),
			Size = UDim2.new(1, -24, 0, 14),
			Text = string.upper(props.label),
			TextColor3 = Theme.Colors.MutedText,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Value = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Number,
			Position = UDim2.fromOffset(14, 20),
			Size = UDim2.new(1, -24, 0, 22),
			Text = props.currency and Format.currency(animatedValue) or Format.compactNumber(animatedValue),
			TextColor3 = Theme.Colors.Text,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

return StatPill
