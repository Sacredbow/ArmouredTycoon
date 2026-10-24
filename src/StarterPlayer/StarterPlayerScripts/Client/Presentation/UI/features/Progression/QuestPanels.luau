local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local QuestOptions = require(ReplicatedStorage.Shared.Game.Progression.QuestOptions)
local InterfaceKit = require(script.Parent.Parent.Parent.shared.InterfaceKit)
local e = React.createElement

local QUEST_DEFINITIONS = QuestOptions.Definitions
local corner = InterfaceKit.Corner
local gradientRich = InterfaceKit.GradientRich
local noticeGradient = InterfaceKit.NoticeGradient
local formatDuration = InterfaceKit.FormatDuration
local useTweenNumber = InterfaceKit.UseTweenNumber
local TitleLine = InterfaceKit.TitleLine
local textLabel = InterfaceKit.TextLabel
local solidButton = InterfaceKit.SolidButton

local function questRow(props)
	local progress = math.clamp(props.progress / props.goal, 0, 1)
	local animatedProgress = useTweenNumber(progress, 0.4, "OutCubic")
	local statusText = if props.claimed
		then "CLAIMED"
		elseif props.completed then "COMPLETED - CLAIM"
		else `{math.floor(props.progress)} / {props.goal}`

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(11, 16, 25),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(520, 104),
	}, {
		Corner = corner(16),
		Stroke = e("UIStroke", {
			Color = props.accent,
			Thickness = 1.25,
			Transparency = 0.45,
		}),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 22, 34)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 16, 26)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 18)),
		}, 135),
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(18, 14),
			Size = UDim2.fromOffset(282, 24),
			Text = props.title,
			TextColor3 = Color3.fromRGB(244, 248, 255),
			TextScaled = false,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Subtitle = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(18, 40),
			Size = UDim2.fromOffset(310, 20),
			Text = props.subtitle,
			TextColor3 = Color3.fromRGB(154, 168, 187),
			TextScaled = false,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Track = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(24, 31, 43),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(18, 68),
			Size = UDim2.fromOffset(312, 13),
		}, {
			Corner = corner(8),
			Fill = e("Frame", {
				BackgroundColor3 = props.accent,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				Size = UDim2.fromScale(animatedProgress, 1),
			}, {
				Corner = corner(8),
				Gradient = gradientRich({
					ColorSequenceKeypoint.new(0, props.accent),
					ColorSequenceKeypoint.new(0.6, props.accent),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
				}, 90),
				EndGlow = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.14,
					BorderSizePixel = 0,
					Position = UDim2.new(1, 2, 0.5, 0),
					Size = UDim2.fromOffset(10, 22),
					Visible = animatedProgress > 0.03,
				}, {
					Corner = corner(8),
					Glow = e("UIStroke", {
						Color = props.accent,
						Thickness = 6,
						Transparency = 0.45,
					}),
				}),
			}),
			Text = textLabel({
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				Text = if props.completed then (if props.claimed then "COMPLETED" else "CLAIM") else "",
				TextColor3 = Color3.fromRGB(5, 9, 14),
				TextScaled = false,
				TextSize = 10,
			}),
		}),
		Count = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(18, 83),
			Size = UDim2.fromOffset(156, 18),
			Text = statusText,
			TextColor3 = props.accent,
			TextScaled = false,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Reward = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(176, 83),
			Size = UDim2.fromOffset(156, 18),
			Text = props.reward,
			TextColor3 = Color3.fromRGB(166, 181, 201),
			TextScaled = false,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Claim = solidButton({
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = if props.claimed then Color3.fromRGB(35, 42, 53) else props.accent,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -18, 0.5, 0),
			Size = UDim2.fromOffset(118, 42),
			Text = if props.claimed then "Done" elseif props.completed then "CLAIM" else props.reward,
			TextColor3 = if props.completed and not props.claimed
				then Color3.fromRGB(4, 9, 14)
				else Color3.fromRGB(174, 185, 201),
			TextScaled = false,
			TextSize = if props.completed then 15 else 12,
			onActivated = if props.completed and not props.claimed then props.claim else nil,
		}, {
			Corner = corner(14),
			Gradient = if props.completed and not props.claimed
				then gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(0.3, props.accent),
					ColorSequenceKeypoint.new(1, props.accent),
				}, 90)
				else gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 50, 62)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 34, 44)),
				}, 135),
		}),
	})
end

local function QuestsPanel(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.5, "OutBack")
	local slideX = useTweenNumber(if props.visible then 0 else 80, 0.22, "OutSine")
	local profile = props.profile
	local selectedCategory, setSelectedCategory = React.useState("Daily")
	local questChildren = {}
	local layoutOrder = 0

	for _, definition in QUEST_DEFINITIONS do
		if definition.category == selectedCategory then
			layoutOrder += 1
			local quest = profile.quests[definition.id]
				or {
					Progress = 0,
					Completed = false,
					Claimed = false,
				}
			questChildren[definition.id] = e(questRow, {
				LayoutOrder = layoutOrder,
				title = definition.title,
				subtitle = definition.subtitle,
				reward = definition.reward,
				progress = quest.Progress,
				goal = definition.goal,
				completed = quest.Completed,
				claimed = quest.Claimed,
				accent = definition.accent,
				claim = function()
					props.claimQuest(definition.id)
				end,
			})
		end
	end

	local resetSeconds = if selectedCategory == "Daily"
		then (tonumber(profile.dailyQuestSecondsRemaining) or 86400)
		else (tonumber(profile.weeklyQuestSecondsRemaining) or 604800)
	local resetText = `Resets in {formatDuration(resetSeconds)}`

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 12, 19),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5 + (slideX / 1000), 0.52),
		Size = UDim2.fromOffset(620, 500),
		Visible = props.visible or appear > 0.02,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * appear,
		}),
		Corner = corner(22),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.5, Transparency = 0.28 }),
		Gradient = noticeGradient(),
		GlassOverlay = nil,
		Title = textLabel(
			{
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(30, 24),
				Size = UDim2.fromOffset(230, 34),
				Text = "Quests",
				TextScaled = false,
				TextSize = 30,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			{
				Line = e(TitleLine, {
					visible = props.visible,
					position = UDim2.new(-0.087, 0, 1, 0),
				}),
			}
		),
		Reset = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(32, 60),
			Size = UDim2.fromOffset(250, 20),
			Text = resetText,
			TextColor3 = Color3.fromRGB(154, 168, 187),
			TextScaled = false,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Close = solidButton(
			{
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
			},
			{
				Corner = corner(14),
				Gradient = gradientRich(
					{
						ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 24, 32)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 14, 20)),
					},
					135
				),
			}
		),
		Tabs = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 17, 26),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(322, 28),
			Size = UDim2.fromOffset(180, 42),
		}, {
			Corner = corner(13),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 22, 32)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 18)),
			}, 135),
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
			Daily = solidButton({
				BackgroundColor3 = if selectedCategory == "Daily"
					then Color3.fromRGB(22, 58, 82)
					else Color3.fromRGB(18, 24, 35),
				LayoutOrder = 1,
				Size = UDim2.fromOffset(81, 30),
				Text = "Daily",
				TextColor3 = if selectedCategory == "Daily"
					then Color3.fromRGB(188, 226, 255)
					else Color3.fromRGB(185, 195, 210),
				TextScaled = false,
				TextSize = 13,
				onActivated = function()
					setSelectedCategory("Daily")
				end,
			}, {
				Corner = corner(10),
				Gradient = if selectedCategory == "Daily"
					then gradientRich({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 70, 100)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 48, 72)),
					}, 135)
					else gradientRich({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 30, 42)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 20, 30)),
					}, 135),
			}),
			Weekly = solidButton({
				BackgroundColor3 = if selectedCategory == "Weekly"
					then Color3.fromRGB(37, 27, 62)
					else Color3.fromRGB(18, 24, 35),
				LayoutOrder = 2,
				Size = UDim2.fromOffset(81, 30),
				Text = "Weekly",
				TextColor3 = if selectedCategory == "Weekly"
					then Color3.fromRGB(214, 199, 255)
					else Color3.fromRGB(185, 195, 210),
				TextScaled = false,
				TextSize = 13,
				onActivated = function()
					setSelectedCategory("Weekly")
				end,
			}, {
				Corner = corner(10),
				Gradient = if selectedCategory == "Weekly"
					then gradientRich({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 38, 82)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 22, 52)),
					}, 135)
					else gradientRich({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 30, 42)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 20, 30)),
					}, 135),
			}),
		}),
		List = e("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, if selectedCategory == "Daily" then 950 else 820),
			Position = UDim2.fromOffset(40, 100),
			ScrollBarImageColor3 = Color3.fromRGB(77, 171, 247),
			ScrollBarThickness = 4,
			Size = UDim2.fromOffset(540, 360),
		}, {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
			Rows = React.createElement(React.Fragment, nil, questChildren),
		}),
	})
end

local function DailyPanel(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.25, "OutSine")
	local slideY = useTweenNumber(if props.visible then 0 else 60, 0.22, "OutSine")
	local remaining = tonumber(props.profile.dailySecondsRemaining) or 86400
	local loaded = (tonumber(props.profile.dailyReadyAt) or 0) > 0
	local ready = loaded and remaining <= 0
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 12, 19),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.52 + (slideY / 1000)),
		Size = UDim2.fromOffset(500, 310),
		Visible = props.visible or appear > 0.02,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.85 + appear * 0.15),
		}),
		Corner = corner(22),
		Stroke = e("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.5, Transparency = 0.24 }),
		Gradient = noticeGradient(),
		GlassOverlay = nil,
		Title = textLabel(
			{
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(30, 28),
				Size = UDim2.fromOffset(300, 34),
				Text = "Daily Reward",
				TextScaled = false,
				TextSize = 30,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			{
				Line = e(TitleLine, {
					visible = props.visible,
					position = UDim2.new(-0.087, 0, 1, 0),
				}),
			}
		),
		Close = solidButton(
			{
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
			},
			{
				Corner = corner(14),
				Gradient = gradientRich(
					{
						ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 24, 32)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 14, 20)),
					},
					135
				),
			}
		),
		Reward = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(42, 104),
			Size = UDim2.fromOffset(410, 54),
			Text = if ready
				then "Your cash bonus is ready."
				elseif loaded then "Daily bonus is cooling down."
				else "Checking your reward...",
			TextColor3 = Color3.fromRGB(255, 221, 146),
			TextScaled = false,
			TextSize = 26,
		}),
		Timer = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(42, 166),
			Size = UDim2.fromOffset(410, 30),
			Text = if ready
				then "Come back every 24 hours for another payout."
				elseif loaded then "Come back tomorrow."
				else "Syncing reward timer...",
			TextColor3 = Color3.fromRGB(167, 180, 198),
			TextScaled = false,
			TextSize = 15,
		}),
		Claim = solidButton(
			{
				BackgroundColor3 = if ready then Color3.fromRGB(255, 190, 73) else Color3.fromRGB(35, 42, 53),
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(138, 224),
				Size = UDim2.fromOffset(224, 52),
				Text = if ready then "Collect" else "Locked",
				TextColor3 = if ready then Color3.fromRGB(11, 8, 3) else Color3.fromRGB(174, 185, 201),
				TextScaled = false,
				TextSize = 20,
				onActivated = if ready then props.claimDaily else nil,
			},
			{
				Corner = corner(16),
				Gradient = if ready
					then gradientRich(
						{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
							ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 190, 73)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 73)),
						},
						90
					)
					else gradientRich(
						{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 50, 62)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 34, 44)),
						},
						135
					),
				Stroke = e(
					"UIStroke",
					{
						Color = if ready then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(70, 82, 101),
						Thickness = 1,
						Transparency = if ready then 0.5 else 0.4,
					}
				),
			}
		),
	})
end

return {
	Quests = QuestsPanel,
	Daily = DailyPanel,
}
