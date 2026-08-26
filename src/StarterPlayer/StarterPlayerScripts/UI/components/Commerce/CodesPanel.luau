local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local InterfaceKit = require(script.Parent.Parent.Kit.InterfaceKit)
local e = React.createElement

local corner = InterfaceKit.Corner
local gradientRich = InterfaceKit.GradientRich
local noticeGradient = InterfaceKit.NoticeGradient
local useTweenNumber = InterfaceKit.UseTweenNumber
local TitleLine = InterfaceKit.TitleLine
local textLabel = InterfaceKit.TextLabel
local solidButton = InterfaceKit.SolidButton

local function CodesPanel(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.5, "OutBack")
	local slideY = useTweenNumber(if props.visible then 0 else 60, 0.22, "OutSine")
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 12, 19),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5 + (slideY / 1000)),
		Size = UDim2.fromOffset(560, 330),
		Visible = props.visible or appear > 0.02,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.85 + appear * 0.15),
		}),
		Corner = corner(22),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1.5,
			Transparency = 0.26,
		}),
		Gradient = noticeGradient(),
		GlassOverlay = nil,
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(28, 26),
			Size = UDim2.fromOffset(210, 34),
			Text = "Codes",
			TextColor3 = Color3.fromRGB(246, 249, 255),
			TextScaled = false,
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			Line = e(TitleLine, {
				visible = props.visible,
				position = UDim2.new(-0.087, 0, 1, 0),
			}),
		}),
		Info = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(30, 68),
			Size = UDim2.fromOffset(420, 42),
			Text = "Drop a code here for quick rewards. Follow @Sacredbow1 for future releases.",
			TextColor3 = Color3.fromRGB(167, 180, 198),
			TextScaled = false,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		Close = solidButton({
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromRGB(42, 18, 24),
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -22, 0, 22),
			Size = UDim2.fromOffset(44, 44),
			Text = "X",
			TextColor3 = Color3.fromRGB(255, 215, 222),
			TextScaled = false,
			TextSize = 18,
			onActivated = props.close,
		}, {
			Corner = corner(14),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 24, 32)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 14, 20)),
			}, 135),
		}),
		Input = e("TextBox", {
			BackgroundColor3 = Color3.fromRGB(12, 17, 26),
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = Enum.Font.GothamBold,
			PlaceholderText = "Enter code",
			Position = UDim2.fromOffset(72, 132),
			Size = UDim2.fromOffset(416, 54),
			Text = props.codeText,
			TextColor3 = if props.feedbackText then props.feedbackColor else Color3.fromRGB(255, 255, 255),
			TextScaled = false,
			TextSize = 18,
			TextTransparency = 0,
			PlaceholderColor3 = Color3.fromRGB(99, 112, 130),
			[React.Change.Text] = function(rbx)
				props.setCodeText(rbx.Text)
			end,
		}, {
			Corner = corner(14),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 22, 32)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 17, 26)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 18)),
			}, 135),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(74, 222, 128),
				Thickness = 1,
				Transparency = 0.52,
			}),
		}),
		Redeem = solidButton({
			BackgroundColor3 = Color3.fromRGB(74, 222, 128),
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(168, 212),
			Size = UDim2.fromOffset(224, 54),
			Text = "Redeem",
			TextColor3 = Color3.fromRGB(5, 14, 10),
			TextScaled = false,
			TextSize = 22,
			onActivated = props.redeem,
		}, {
			Corner = corner(16),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.3, Color3.fromRGB(74, 222, 128)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(74, 222, 128)),
			}, 90),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1,
				Transparency = 0.5,
			}),
		}),
		Feedback = props.feedbackText and textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(70, 280),
			Size = UDim2.fromOffset(420, 26),
			Text = props.feedbackText,
			TextColor3 = props.feedbackColor,
			TextScaled = false,
			TextSize = 15,
		}) or nil,
	})
end


return CodesPanel
