local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local InterfaceKit = require(script.Parent.Parent.Parent.Parent.shared.InterfaceKit)
local e = React.createElement

local corner = InterfaceKit.Corner
local stroke = InterfaceKit.Stroke
local gradientRich = InterfaceKit.GradientRich
local noticeGradient = InterfaceKit.NoticeGradient
local useTweenNumber = InterfaceKit.UseTweenNumber
local TitleLine = InterfaceKit.TitleLine
local textLabel = InterfaceKit.TextLabel
local solidButton = InterfaceKit.SolidButton

local function LootboxPanel(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.5, "OutBack")
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 30, 45),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.3, 0.208),
		Size = UDim2.fromScale(0.647, 0.702),
		Visible = props.visible or appear > 0.02,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.85 + appear * 0.15),
		}),
		Aspect = e("UIAspectRatioConstraint", { AspectRatio = 1.746 }),
		Corner = corner(),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1.5,
			Transparency = 0.22,
		}),
		Gradient = noticeGradient(),
		Sign = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://97953307997580",
			Position = UDim2.fromScale(-0.141, -0.105),
			Size = UDim2.fromScale(0.538, 0.285),
		}, {
			Label = textLabel({
				Position = UDim2.fromScale(0.19, 0.095),
				Size = UDim2.fromScale(0.513, 0.8),
				Text = "Lootbox",
				TextColor3 = Color3.fromRGB(85, 255, 255),
			}),
		}),
		Close = solidButton({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(170, 68, 65),
			Position = UDim2.fromScale(0.997, 0.003),
			Size = UDim2.fromScale(0.072, 0.112),
			Text = "X",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			onActivated = props.close,
		}, {
			Corner = corner(),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 80, 76)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 50, 48)),
			}, 135),
			Stroke = stroke(),
		}),
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(0.227, 0.127),
			Size = UDim2.fromOffset(333, 41),
			Text = "Lootbox Requirement",
			TextColor3 = Color3.fromRGB(246, 249, 255),
			TextScaled = false,
			TextSize = 28,
		}, {
			Line = e(TitleLine, {
				visible = props.visible,
				position = UDim2.new(-0.087, 0, 1, 0),
			}),
		}),
		Profile = e("ImageLabel", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Image = props.profileImage,
			Position = UDim2.fromScale(0.429, 0.291),
			Size = UDim2.fromOffset(100, 100),
		}, {
			Corner = corner(),
		}),
		Info = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromScale(0.093, 0.637),
			Size = UDim2.fromScale(0.875, 0.138),
			Text = "You will need to follow @Sacredbow1, to claim the Mythical Lootbox!",
			TextColor3 = Color3.fromRGB(178, 190, 208),
			TextScaled = false,
			TextSize = 14,
		}),
		Copy = e("TextBox", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromScale(0.091, 0.832),
			Size = UDim2.fromScale(0.858, 0.124),
			Text = "https://www.roblox.com/users/1372952359/profile",
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextSize = 14,
		}, {
			Corner = corner(),
		}),
	})
end

return LootboxPanel
