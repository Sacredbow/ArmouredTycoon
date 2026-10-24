local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local InterfaceKit = require(script.Parent.Parent.Parent.shared.InterfaceKit)
local e = React.createElement

local corner = InterfaceKit.Corner
local gradient = InterfaceKit.Gradient
local gradientRich = InterfaceKit.GradientRich
local noticeGradient = InterfaceKit.NoticeGradient
local useTweenNumber = InterfaceKit.UseTweenNumber
local TitleLine = InterfaceKit.TitleLine
local textLabel = InterfaceKit.TextLabel
local solidButton = InterfaceKit.SolidButton

local function outCubic(alpha: number): number
	return 1 - ((1 - alpha) ^ 3)
end

local function levelRing(props)
	local progress = math.clamp(props.progress or 0, 0, 1)
	local children = {}
	local segments = 28
	local radius = 78
	for index = 1, segments do
		local angle = ((index - 1) / segments) * math.pi * 2 - math.pi / 2
		local active = index / segments <= progress
		children[`Segment{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if active then Color3.fromRGB(68, 186, 255) else Color3.fromRGB(24, 31, 43),
			BackgroundTransparency = if active then 0 else 0.22,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(96 + math.cos(angle) * radius, 96 + math.sin(angle) * radius),
			Rotation = math.deg(angle) + 90,
			Size = UDim2.fromOffset(8, 22),
		}, {
			Corner = corner(8),
			Glow = nil,
			Gradient = active and gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(68, 186, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 255)),
			}, 90) or nil,
		})
	end

	children.Inner = e("Frame", {
		BackgroundColor3 = Color3.fromRGB(3, 6, 11),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(34, 34),
		Size = UDim2.fromOffset(124, 124),
	}, {
		Corner = corner(62),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(57, 147, 255),
			Thickness = 1,
			Transparency = 0.55,
		}),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 12, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 6, 11)),
		}, 135),
		Level = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.fromOffset(124, 44),
			Text = tostring(props.level),
			TextColor3 = Color3.fromRGB(238, 248, 255),
			TextScaled = false,
			TextSize = 38,
		}),
		Label = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(0, 76),
			Size = UDim2.fromOffset(124, 22),
			Text = "LEVEL",
			TextColor3 = Color3.fromRGB(111, 202, 255),
			TextScaled = false,
			TextSize = 12,
		}),
	})

	return e("Frame", {
		BackgroundTransparency = 1,
		Position = props.Position,
		Size = UDim2.fromOffset(192, 192),
	}, children)
end

local function statBlock(props)
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(11, 16, 25),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(158, 84),
	}, {
		Corner = corner(16),
		Stroke = e("UIStroke", {
			Color = props.accent,
			Thickness = 1.25,
			Transparency = 0.38,
		}),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 22, 34)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 16, 26)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 18)),
		}, 135),
		Label = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(14, 12),
			Size = UDim2.fromOffset(130, 18),
			Text = string.upper(props.label),
			TextColor3 = Color3.fromRGB(142, 157, 178),
			TextScaled = false,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(14, 34),
			Size = UDim2.fromOffset(130, 32),
			Text = props.value,
			TextColor3 = props.accent,
			TextScaled = false,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function ProfileView(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.5, "OutBack")
	local slideX = useTweenNumber(if props.visible then 0 else -80, 0.22, "OutSine")
	local stats = props.stats
	local profile = props.profile
	local progress = math.clamp(profile.experience / math.max(profile.requiredExperience, 1), 0, 1)
	local animatedProgress, setAnimatedProgress = React.useState(progress)

	React.useEffect(function()
		local cancelled = false
		local start = if props.visible then 0 else animatedProgress
		task.spawn(function()
			for step = 1, 22 do
				if cancelled then
					return
				end
				local alpha = step / 22
				local eased = outCubic(alpha)
				setAnimatedProgress(start + ((progress - start) * eased))
				task.wait(0.016)
			end
			if not cancelled then
				setAnimatedProgress(progress)
			end
		end)

		return function()
			cancelled = true
		end
	end, { progress, props.visible })

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 12, 19),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5 - (slideX / 1000), 0.52),
		Size = UDim2.fromOffset(700, 380),
		Visible = props.visible or appear > 0.02,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.85 + appear * 0.15),
		}),
		Corner = corner(22),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1.5,
			Transparency = 0.28,
		}),
		Gradient = noticeGradient(),
		GlassOverlay = nil,
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(30, 24),
			Size = UDim2.fromOffset(250, 34),
			Text = "Profile",
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
		Avatar = e("ImageLabel", {
			BackgroundColor3 = Color3.fromRGB(3, 6, 11),
			BorderSizePixel = 0,
			Image = props.profileImage,
			Position = UDim2.fromOffset(34, 78),
			Size = UDim2.fromOffset(106, 106),
		}, {
			Corner = corner(53),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(68, 186, 255),
				Thickness = 2,
				Transparency = 0.18,
			}),
		}),
		Ring = e(levelRing, {
			Position = UDim2.fromOffset(176, 52),
			level = profile.level,
			progress = animatedProgress,
		}),
		XPCounter = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(176, 238),
			Size = UDim2.fromOffset(180, 22),
			Text = `{profile.experience} / {profile.requiredExperience} XP`,
			TextColor3 = Color3.fromRGB(137, 213, 255),
			TextScaled = false,
			TextSize = 14,
		}),
		Stats = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(406, 116),
			Size = UDim2.fromOffset(236, 92),
		}, {
			Grid = e("UIGridLayout", {
				CellPadding = UDim2.fromOffset(12, 12),
				CellSize = UDim2.fromOffset(112, 84),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Rebirths = e(
				statBlock,
				{
					LayoutOrder = 1,
					label = "Rebirths",
					value = tostring(stats.Rebirths),
					accent = Color3.fromRGB(255, 190, 73),
				}
			),
			Kills = e(
				statBlock,
				{
					LayoutOrder = 2,
					label = "Kills",
					value = tostring(stats.Kills),
					accent = Color3.fromRGB(255, 93, 112),
				}
			),
		}),
	})
end

return ProfileView
