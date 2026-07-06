local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)
local Format = require(script.Parent.Parent.Parent.utils.Format)
local InterfaceKit = require(script.Parent.InterfaceKit)
local e = React.createElement

local corner = InterfaceKit.Corner
local gradient = InterfaceKit.Gradient
local gradientRich = InterfaceKit.GradientRich
local shimmerGradient = InterfaceKit.ShimmerGradient
local noticeGradient = InterfaceKit.NoticeGradient
local useTweenNumber = InterfaceKit.UseTweenNumber
local textLabel = InterfaceKit.TextLabel
local imageButton = InterfaceKit.ImageButton
local solidButton = InterfaceKit.SolidButton

local CurrencyAnimationDuration = 1.5
local CashGainColor = Color3.fromRGB(86, 255, 132)
local CashLossColor = Color3.fromRGB(255, 82, 82)

local function AnimatedCurrencyAmount(Props)
	local Target = Props.Value :: number
	local Accent = Props.Accent :: Color3
	local FormatValue = Props.FormatValue
	local CurrentRef = React.useRef(Target)
	local AnimationRef = React.useRef(0)
	local Display, SetDisplay = React.useState({
		Value = Target,
		Color = Accent,
	})

	React.useEffect(function()
		local StartValue = CurrentRef.current
		if StartValue == Target then
			SetDisplay({ Value = Target, Color = Accent })
			return
		end

		AnimationRef.current += 1
		local AnimationId = AnimationRef.current
		local StartTime = os.clock()
		local ChangeColor = if Target > StartValue then CashGainColor else CashLossColor
		local Connection: RBXScriptConnection?

		Connection = RunService.RenderStepped:Connect(function()
			if AnimationRef.current ~= AnimationId then
				return
			end

			local Alpha = math.clamp((os.clock() - StartTime) / CurrencyAnimationDuration, 0, 1)
			local EasedAlpha = Alpha * Alpha * (3 - 2 * Alpha)
			local Value = StartValue + (Target - StartValue) * EasedAlpha
			local ColorReturnAlpha = math.clamp((Alpha - 0.82) / 0.18, 0, 1)
			local Color = ChangeColor:Lerp(Accent, ColorReturnAlpha)

			CurrentRef.current = Value
			SetDisplay({ Value = Value, Color = Color })

			if Alpha >= 1 then
				CurrentRef.current = Target
				SetDisplay({ Value = Target, Color = Accent })
				if Connection then
					Connection:Disconnect()
					Connection = nil
				end
			end
		end)

		return function()
			AnimationRef.current += 1
			if Connection then
				Connection:Disconnect()
				Connection = nil
			end
		end
	end, { Target })

	return textLabel({
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(58, 19),
		RichText = true,
		Size = UDim2.fromOffset(124, 28),
		Text = "<b>" .. FormatValue(math.round(Display.Value)) .. "</b>",
		TextColor3 = Display.Color,
		TextScaled = false,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function currencyPill(props : any)
	local accent = props.accent

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(13, 17, 23),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(238, 56),
	}, {
		Corner = corner(12),
		Stroke = e("UIStroke", {
			Color = accent,
			Thickness = 1.5,
			Transparency = 0.35,
		}),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 28, 38)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 18, 26)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 16)),
		}, 135),

		IconBack = e("Frame", {
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(40, 40),
		}, {
			Corner = corner(10),
			Gradient = shimmerGradient(accent, 135),
			Icon = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = props.icon,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(31, 31),
			}),
		}),

		Label = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(58, 6),
			Size = UDim2.fromOffset(104, 16),
			Text = string.upper(props.label),
			TextColor3 = Color3.fromRGB(147, 159, 174),
			TextScaled = false,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Amount = if props.numericValue ~= nil then e(AnimatedCurrencyAmount, {
			Value = props.numericValue,
			Accent = accent,
			FormatValue = props.formatValue,
		}) else textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(58, 19),
			RichText = true,
			Size = UDim2.fromOffset(124, 28),
			Text = "<b>" .. props.value .. "</b>",
			TextColor3 = accent,
			TextScaled = false,
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Add = solidButton({
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = accent,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -11, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			Text = "+",
			TextColor3 = Color3.fromRGB(7, 12, 9),
			TextSize = 24,
			TextScaled = false,
			onActivated = props.onAdd,
		}, {
			Corner = corner(17),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.5, accent),
				ColorSequenceKeypoint.new(1, accent),
			}, 90),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1,
				Transparency = 0.68,
			}),
		}),
	})
end

local function hudActionButton(props)
	return solidButton({
		BackgroundColor3 = Color3.fromRGB(17, 22, 30),
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(116, 48),
		Text = "",
		onActivated = props.onActivated,
	}, {
		Corner = corner(12),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(68, 82, 102),
			Thickness = 1,
			Transparency = 0.18,
		}),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 34, 48)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 24, 34)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 14, 20)),
		}, 135),
		Icon = e("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = props.icon,
			ImageColor3 = Color3.fromRGB(238, 244, 255),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
		}),
		Label = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(42, 7),
			Size = UDim2.fromOffset(66, 20),
			Text = props.label,
			TextColor3 = Color3.fromRGB(238, 244, 255),
			TextScaled = false,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Sub = props.subText and textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(42, 25),
			Size = UDim2.fromOffset(66, 14),
			Text = props.subText,
			TextColor3 = Color3.fromRGB(139, 154, 174),
			TextScaled = false,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		}) or nil,
	})
end

local function CurrencyHud(props)
	local stats = props.stats
	local openShop = props.openShop
	local openMenu = props.openMenu
	local openStats = props.openStats

	return e("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 22, 0.34, 0),
		Size = UDim2.fromOffset(248, 176),
		Visible = not props.hidden,
	}, {
		Scale = e("UIScale", {
			Scale = props.uiScale or 1,
		}),
		CurrencyList = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(238, 120),
		}, {
			List = e("UIListLayout", {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Cash = e(currencyPill, {
				LayoutOrder = 1,
				accent = Color3.fromRGB(255, 190, 73),
				icon = "rbxassetid://89191903151861",
				label = "Cash",
				numericValue = stats.Cash,
				formatValue = Format.currency,
				onAdd = function()
					openShop("Money")
				end,
			}),
			Emerald = e(currencyPill, {
				LayoutOrder = 2,
				accent = Color3.fromRGB(62, 236, 119),
				icon = "rbxassetid://101370548562567",
				label = "Emeralds",
				value = Format.compactNumber(stats.Emerald),
				onAdd = function()
					openShop("Money")
				end,
			}),
		}),

		Actions = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 128),
			Size = UDim2.fromOffset(240, 48),
		}, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Menu = e(hudActionButton, {
				LayoutOrder = 1,
				icon = "rbxassetid://4773248567",
				label = "Menu",
				subText = "Open",
				onActivated = openMenu,
			}),
			Stats = e(hudActionButton, {
				LayoutOrder = 2,
				icon = "rbxassetid://8587689304",
				label = "Profile",
				subText = "Level",
				onActivated = openStats,
			}),
		}),
	})
end


return CurrencyHud
