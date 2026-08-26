local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local InterfaceKit = require(script.Parent.Parent.Kit.InterfaceKit)
local e = React.createElement

local corner = InterfaceKit.Corner
local gradientRich = InterfaceKit.GradientRich
local noticeGradient = InterfaceKit.NoticeGradient
local useTweenNumber = InterfaceKit.UseTweenNumber
local textLabel = InterfaceKit.TextLabel

local function LevelUpPresentation(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.5, "OutElastic")
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(3, 8, 16),
		BackgroundTransparency = if props.visible then 0.14 else 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.18),
		Size = UDim2.fromOffset(360, 92),
		Visible = props.visible or appear > 0.02,
		ZIndex = 50,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.6 + appear * 0.4),
		}),
		Corner = corner(24),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1,
			Transparency = 0.68,
		}),
		Gradient = noticeGradient(),
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.fromOffset(360, 34),
			Text = "LEVEL UP",
			TextColor3 = Color3.fromRGB(112, 217, 255),
			TextScaled = false,
			TextSize = 28,
			ZIndex = 51,
		}, {
			TextGradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 240, 255)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(112, 217, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(68, 186, 255)),
				}),
				Rotation = 90,
			}),
		}),
		Sub = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.fromOffset(360, 24),
			Text = `You reached Level {props.level}`,
			TextColor3 = Color3.fromRGB(238, 248, 255),
			TextScaled = false,
			TextSize = 17,
			ZIndex = 51,
		}, {
			TextGradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 220, 255)),
				}),
				Rotation = 90,
			}),
		}),
	})
end


return LevelUpPresentation
