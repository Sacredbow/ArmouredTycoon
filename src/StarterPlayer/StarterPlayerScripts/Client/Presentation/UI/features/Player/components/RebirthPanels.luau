local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local InterfaceKit = require(script.Parent.Parent.Parent.Parent.shared.InterfaceKit)
local e = React.createElement

local corner = InterfaceKit.Corner
local gradientRich = InterfaceKit.GradientRich
local shimmerGradient = InterfaceKit.ShimmerGradient
local noticeGradient = InterfaceKit.NoticeGradient
local useTweenNumber = InterfaceKit.UseTweenNumber
local TitleLine = InterfaceKit.TitleLine
local textLabel = InterfaceKit.TextLabel
local solidButton = InterfaceKit.SolidButton

local function RebirthButton(props)
	local shown = props.visible
	local appear = useTweenNumber(if shown then 1 else 0, 0.28, "OutBack")

	return solidButton({
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 190, 73),
		Position = UDim2.new(1, -28, 0.54, 0),
		Size = UDim2.fromOffset(168, 58),
		Text = "",
		Visible = shown or appear > 0.02,
		ZIndex = 32,
		onActivated = props.onActivated,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.7 + appear * 0.3),
		}),
		Corner = corner(17),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1.5,
			Transparency = 0.3,
		}),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 200)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 205, 88)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 170, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 132, 48)),
		}, 90),
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(18, 9),
			Size = UDim2.fromOffset(132, 24),
			Text = "REBIRTH",
			TextColor3 = Color3.fromRGB(18, 12, 4),
			TextScaled = false,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 33,
		}),
		Sub = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(18, 34),
			Size = UDim2.fromOffset(132, 16),
			Text = "Reset for +1",
			TextColor3 = Color3.fromRGB(56, 35, 10),
			TextScaled = false,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 33,
		}),
	})
end

local function RebirthConfirmPanel(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.5, "OutBack")
	local slideY = useTweenNumber(if props.visible then 0 else 70, 0.22, "OutSine")

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 12, 19),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.52 + (slideY / 1000)),
		Size = UDim2.fromOffset(520, 286),
		Visible = props.visible or appear > 0.02,
		ZIndex = 45,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.85 + appear * 0.15),
		}),
		Corner = corner(22),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 16, 6)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(18, 13, 5)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(14, 10, 4)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 7, 3)),
		}, 135),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.48 }),
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(18, 9),
			Size = UDim2.fromOffset(300, 24),
			Text = "CONFIRM REBIRTH",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = false,
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 46,
		}, {
			Line = e(TitleLine, {
				visible = props.visible,
				position = UDim2.new(-0.087, 0, 1, 0),
			}),
		}),
		Body = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(32, 88),
			Size = UDim2.fromOffset(456, 72),
			Text = "Are you sure? Your current tycoon build will reset, your cash will return to the starter amount, and you will gain +1 rebirth.",
			TextColor3 = Color3.fromRGB(178, 190, 208),
			TextScaled = false,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 46,
		}),
		Cancel = solidButton({
			BackgroundColor3 = Color3.fromRGB(36, 44, 58),
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(46, 196),
			Size = UDim2.fromOffset(190, 52),
			Text = "Cancel",
			TextColor3 = Color3.fromRGB(224, 232, 244),
			TextScaled = false,
			TextSize = 18,
			ZIndex = 46,
			onActivated = props.close,
		}, {
			Corner = corner(16),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(83, 99, 122), Thickness = 1, Transparency = 0.22 }),
		}),
		Confirm = solidButton({
			BackgroundColor3 = Color3.fromRGB(255, 190, 73),
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(284, 196),
			Size = UDim2.fromOffset(190, 52),
			Text = "Rebirth",
			TextColor3 = Color3.fromRGB(15, 9, 2),
			TextScaled = false,
			TextSize = 18,
			ZIndex = 46,
			onActivated = props.confirm,
		}, {
			Corner = corner(16),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.32, Color3.fromRGB(255, 205, 88)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 132, 48)),
			}, 90),
			Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.48 }),
		}),
	})
end

return {
	Button = RebirthButton,
	Confirmation = RebirthConfirmPanel,
}
