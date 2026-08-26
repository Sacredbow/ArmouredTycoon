local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local InterfaceKit = require(script.Parent.Parent.Kit.InterfaceKit)
local e = React.createElement

local corner = InterfaceKit.Corner
local gradient = InterfaceKit.Gradient
local gradientRich = InterfaceKit.GradientRich
local noticeGradient = InterfaceKit.NoticeGradient
local useTweenNumber = InterfaceKit.UseTweenNumber
local textLabel = InterfaceKit.TextLabel
local solidButton = InterfaceKit.SolidButton

local function MenuButton(props)
	return solidButton({
		BackgroundColor3 = Color3.fromRGB(14, 19, 28),
		Position = props.position,
		Size = UDim2.fromOffset(214, 58),
		Text = "",
		onActivated = props.onActivated,
	}, {
		Corner = corner(14),
		Stroke = e("UIStroke", {
			Color = props.accent or Color3.fromRGB(77, 92, 113),
			Thickness = 1.5,
			Transparency = 0.22,
		}),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 36, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 24, 36)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 13, 20)),
		}, 135),
		Accent = e("Frame", {
			BackgroundColor3 = props.accent or Color3.fromRGB(89, 169, 255),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(0, 5, 1, 0),
		}, {
			Corner = corner(14),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.4, props.accent or Color3.fromRGB(89, 169, 255)),
				ColorSequenceKeypoint.new(1, props.accent or Color3.fromRGB(89, 169, 255)),
			}, 90),
		}),
		Label = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(18, 9),
			Size = UDim2.fromOffset(166, 24),
			Text = props.text,
			TextColor3 = Color3.fromRGB(241, 245, 249),
			TextScaled = false,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Sub = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(18, 33),
			Size = UDim2.fromOffset(166, 16),
			Text = props.subText or "Open panel",
			TextColor3 = Color3.fromRGB(142, 157, 178),
			TextScaled = false,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		ComingSoon = props.comingSoon and textLabel({
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 64, 92),
			BackgroundTransparency = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(74, 24),
			Text = "COMING SOON",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = false,
			TextSize = 9,
		}, {
			Corner = corner(12),
			Gradient = gradient(Color3.fromRGB(255, 100, 120), Color3.fromRGB(255, 50, 80), 90),
		}) or nil,
	})
end

local function ItemMenu(props)
	local shown = props.open
	local appear = useTweenNumber(if shown then 1 else 0, 0.5, "OutBack")
	local slideX = if shown then 22 else -280

	local buttonAppear = {}
	for i = 1, 7 do
		buttonAppear[i] = useTweenNumber(if shown then 1 else 0, 0.3, "OutBack")
	end

	local function staggeredX(index: number): number
		local a = buttonAppear[index] or 0
		return -280 + (280 + 22) * a
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0.17, 0),
		Size = UDim2.fromOffset(236, 496),
		Visible = true,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.85 + appear * 0.15),
		}),
		Panel = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(10, 12, 18),
			BackgroundTransparency = if shown then 0.08 else 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(if shown then 10 else -274, -12),
			Size = UDim2.fromOffset(236, 496),
		}, {
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1,
				Transparency = 0.45,
			}),
			Gradient = noticeGradient(180),
		}),
		Shop = e(MenuButton, {
			text = "Market Store",
			subText = "",
			accent = Color3.fromRGB(120, 159, 255),
			position = UDim2.fromOffset(staggeredX(1), 0),
			comingSoon = true,
		}),
		Passes = e(MenuButton, {
			text = "Passes",
			subText = "Premium boosts",
			accent = Color3.fromRGB(164, 112, 255),
			position = UDim2.fromOffset(staggeredX(2), 70),
			onActivated = function()
				props.openShop("Passes")
			end,
		}),
		Codes = e(MenuButton, {
			text = "Codes",
			subText = "Redeem rewards",
			accent = Color3.fromRGB(74, 222, 128),
			position = UDim2.fromOffset(staggeredX(3), 140),
			onActivated = props.openCodes,
		}),
		Gift = e(MenuButton, {
			text = "Daily Reward",
			subText = "24 hour bonus",
			accent = Color3.fromRGB(255, 190, 73),
			position = UDim2.fromOffset(staggeredX(4), 210),
			onActivated = props.openDaily,
		}),
		Quests = e(MenuButton, {
			text = "Quests",
			subText = "Earn rewards",
			accent = Color3.fromRGB(77, 171, 247),
			position = UDim2.fromOffset(staggeredX(5), 280),
			onActivated = props.openQuests,
		}),
		Settings = e(MenuButton, {
			text = "Settings",
			subText = "Gameplay / visuals",
			accent = Color3.fromRGB(148, 163, 184),
			position = UDim2.fromOffset(staggeredX(6), 350),
			onActivated = props.openSettings,
		}),
		Exit = e(MenuButton, {
			text = "Exit",
			subText = "Close menu",
			accent = Color3.fromRGB(255, 93, 112),
			position = UDim2.fromOffset(staggeredX(7), 420),
			onActivated = props.closeMenu,
		}),
	})
end


return ItemMenu
