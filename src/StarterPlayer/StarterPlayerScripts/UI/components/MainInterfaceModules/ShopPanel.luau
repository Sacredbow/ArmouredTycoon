local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local InterfaceKit = require(script.Parent.InterfaceKit)
local e = React.createElement

type ShopTab = "Money" | "Passes" | "Boosts"

local corner = InterfaceKit.Corner
local gradientRich = InterfaceKit.GradientRich
local shimmerGradient = InterfaceKit.ShimmerGradient
local noticeGradient = InterfaceKit.NoticeGradient
local useTweenNumber = InterfaceKit.UseTweenNumber
local TitleLine = InterfaceKit.TitleLine
local textLabel = InterfaceKit.TextLabel
local solidButton = InterfaceKit.SolidButton

local PRODUCT_IDS = {
	Cash_5000 = 3450461469,
	Cash_25000 = 3450463123,
	Cash_50000 = 3450470672,
	Cash_250000 = 3450465321,
	Cash_500000 = 3450466129,
	Emerald_300 = 3496915650,
	Emerald_750 = 3496916844,
	Emerald_1250 = 3496917747,
	Emerald_3500 = 3496918338,
	Emerald_10000 = 3496921305,
	ShieldArmour = 3450473810,
}

local GAMEPASS_IDS = {
	SWAT_Gamepass = 1573236427,
	X2Cash = 1568972351,
	Raygun = 1793083522,
}

local MONEY_ITEMS = {
	{ name = "5,000 Cash", image = "rbxassetid://98194995042717", productId = PRODUCT_IDS.Cash_5000 },
	{ name = "25,000 Cash", image = "rbxassetid://89704022531143", productId = PRODUCT_IDS.Cash_25000 },
	{ name = "50,000 Cash", image = "rbxassetid://119437850743750", productId = PRODUCT_IDS.Cash_50000 },
	{ name = "250,000 Cash", image = "rbxassetid://136480123349052", productId = PRODUCT_IDS.Cash_250000 },
	{ name = "500,000 Cash", image = "rbxassetid://74720005491643", productId = PRODUCT_IDS.Cash_500000 },
	{ name = "300 Emeralds", image = "rbxassetid://91259026689940", productId = PRODUCT_IDS.Emerald_300, emerald = true },
	{ name = "750 Emeralds", image = "rbxassetid://111024795809019", productId = PRODUCT_IDS.Emerald_750, emerald = true },
	{ name = "1,250 Emeralds", image = "rbxassetid://73624503395983", productId = PRODUCT_IDS.Emerald_1250, emerald = true },
	{ name = "3,500 Emeralds", image = "rbxassetid://109489500535672", productId = PRODUCT_IDS.Emerald_3500, emerald = true },
	{ name = "10,000 Emeralds", image = "rbxassetid://86305919428662", productId = PRODUCT_IDS.Emerald_10000, emerald = true },
}

local PASS_ITEMS = {
	{
		name = "SWAT Gamepass",
		gamepassId = GAMEPASS_IDS.SWAT_Gamepass,
		description = "This product gives you a SWAT Pack, which includes a HK416, an Armoured Vest (+150 HP), and SWAT Clothing.",
	},
	{
		name = "StarterPack",
		gamepassId = GAMEPASS_IDS.X2Cash,
		description = "This product gives you a StarterPack along with: HK416, +10 HP (permanent) and +$25,000",
	},
	{
		name = "RayGun",
		gamepassId = GAMEPASS_IDS.Raygun,
		description = "This product gives you a RayGun, which one shots, making this the most powerful weapon in the game!",
	},
}

local BOOST_ITEMS = {
	{
		name = "+100 Health",
		description = "This product gives you +100 Health.",
	},
	{
		name = "1.5x Cash Multiplier",
		description = "This product gives you 1.5x Cash Multiplier.",
		notice = "Does not stack. If you purchase this before the duration runs out, it will not add up!",
	},
	{
		name = "Shield Armour",
		productId = PRODUCT_IDS.ShieldArmour,
		description = "This product gives you Shield Armour around you.",
		notice = "Does not stack. If you purchase this before the duration runs out, the shield will not multiply or add up!",
	},
}
local function ProductCard(props)
	local item = props.item
	local accent = if item.emerald
		then Color3.fromRGB(47, 217, 120)
		elseif item.productId
		then Color3.fromRGB(255, 191, 73)
		elseif item.gamepassId
		then Color3.fromRGB(139, 92, 246)
		else Color3.fromRGB(77, 171, 247)
	local tag = if item.emerald then "EMERALDS" elseif item.gamepassId then "PASS" elseif item.productId then "CASH" else "BOOST"

	return solidButton({
		BackgroundColor3 = Color3.fromRGB(15, 20, 30),
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(142, 136),
		Text = "",
		onActivated = function()
			props.onSelected(item)
		end,
	}, {
		Corner = corner(14),
		Stroke = e("UIStroke", {
			Color = accent,
			Thickness = 1.5,
			Transparency = 0.24,
		}),
		Glow = e("UIStroke", {
			Color = accent,
			Thickness = 5,
			Transparency = 0.78,
		}),
		Gradient = gradientRich({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 34, 48)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(16, 22, 34)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 12, 18)),
		}, 135),
		Accent = e("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 4),
		}, {
			Corner = corner(14),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.35, accent),
				ColorSequenceKeypoint.new(1, accent),
			}, 90),
		}),
		Tag = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(78, 16),
			Text = tag,
			TextColor3 = accent,
			TextScaled = false,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		IconBack = e("Frame", {
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.87,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 34),
			Size = UDim2.fromOffset(114, 58),
		}, {
			Corner = corner(12),
			Gradient = shimmerGradient(accent, 135),
			Icon = item.image and e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = item.image,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.76, 0.9),
			}) or textLabel({
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromScale(0, 0.1),
				Size = UDim2.fromScale(1, 0.8),
				Text = if item.gamepassId then "PASS" else "BOOST",
				TextColor3 = accent,
				TextScaled = false,
				TextSize = 20,
			}),
		}),
		Label = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(10, 98),
			Size = UDim2.fromOffset(122, 28),
			Text = item.name,
			TextColor3 = Color3.fromRGB(244, 248, 255),
			TextScaled = false,
			TextSize = 13,
		}),
	})
end

local function itemDescription(item : any)
	if not item then
		return "Select an item to see more details."
	end

	return item.description or ("This product gives you " .. item.name .. ".")
end

local function ShopPanel(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.5, "OutBack")
	local slideX = useTweenNumber(if props.visible then 0 else 80, 0.22, "OutSine")
	local tab: ShopTab = props.tab
	local setTab = props.setTab
	local selectedItem = props.selectedItem
	local setSelectedItem = props.setSelectedItem
	local tabAccent = if tab == "Money"
		then Color3.fromRGB(255, 191, 73)
		elseif tab == "Passes"
		then Color3.fromRGB(139, 92, 246)
		else Color3.fromRGB(77, 171, 247)

	local items = if tab == "Money" then MONEY_ITEMS elseif tab == "Passes" then PASS_ITEMS else BOOST_ITEMS
	local gridChildren = {}

	for index, item in ipairs(items) do
		gridChildren[`Item{index}`] = e(ProductCard, {
			item = item,
			layoutOrder = index,
			onSelected = setSelectedItem,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 12, 19),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.56 + (slideX / 1000), 0.53),
		Size = UDim2.fromOffset(680, 500),
		Visible = props.visible or appear > 0.02,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.85 + appear * 0.15),
		}),
		Corner = corner(20),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1.5,
			Transparency = 0.18,
		}),
		Gradient = noticeGradient(),
		GlassOverlay = nil,

		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(28, 20),
			Size = UDim2.fromOffset(240, 34),
			Text = "Premium Store",
			TextColor3 = Color3.fromRGB(246, 249, 255),
			TextScaled = false,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			Line = e(TitleLine, {
				visible = props.visible,
				position = UDim2.new(-0.087, 0, 1, 0),
			}),
		}),
		SubTitle = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(30, 54),
			Size = UDim2.fromOffset(330, 20),
			Text = "Cash, passes, and boosts in one clean place.",
			TextColor3 = Color3.fromRGB(139, 154, 174),
			TextScaled = false,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Close = solidButton({
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromRGB(42, 18, 24),
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -22, 0, 18),
			Size = UDim2.fromOffset(48, 48),
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
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 93, 112),
				Thickness = 1,
				Transparency = 0.35,
			}),
		}),

		Tabs = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 17, 26),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(26, 88),
			Size = UDim2.fromOffset(430, 52),
		}, {
			Corner = corner(14),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1,
				Transparency = 0.4,
			}),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 22, 32)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 18)),
			}, 135),
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Pad = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			Money = solidButton({
				BackgroundColor3 = if tab == "Money" then Color3.fromRGB(54, 38, 16) else Color3.fromRGB(18, 24, 35),
				LayoutOrder = 1,
				Size = UDim2.fromOffset(130, 36),
				Text = "Money",
				TextColor3 = if tab == "Money" then Color3.fromRGB(255, 214, 125) else Color3.fromRGB(185, 195, 210),
				TextScaled = false,
				TextSize = 15,
				onActivated = function()
					setTab("Money")
				end,
			}, {
				Corner = corner(10),
				Gradient = if tab == "Money" then gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 50, 22)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 30, 12)),
				}, 135) else gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 30, 42)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 20, 30)),
				}, 135),
			}),
			Passes = solidButton({
				BackgroundColor3 = if tab == "Passes" then Color3.fromRGB(37, 27, 62) else Color3.fromRGB(18, 24, 35),
				LayoutOrder = 2,
				Size = UDim2.fromOffset(130, 36),
				Text = "Passes",
				TextColor3 = if tab == "Passes" then Color3.fromRGB(214, 199, 255) else Color3.fromRGB(185, 195, 210),
				TextScaled = false,
				TextSize = 15,
				onActivated = function()
					setTab("Passes")
				end,
			}, {
				Corner = corner(10),
				Gradient = if tab == "Passes" then gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 38, 82)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 22, 52)),
				}, 135) else gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 30, 42)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 20, 30)),
				}, 135),
			}),
			Boosts = solidButton({
				BackgroundColor3 = if tab == "Boosts" then Color3.fromRGB(20, 42, 65) else Color3.fromRGB(18, 24, 35),
				LayoutOrder = 3,
				Size = UDim2.fromOffset(130, 36),
				Text = "Boosts",
				TextColor3 = if tab == "Boosts" then Color3.fromRGB(188, 226, 255) else Color3.fromRGB(185, 195, 210),
				TextScaled = false,
				TextSize = 15,
				onActivated = function()
					setTab("Boosts")
				end,
			}, {
				Corner = corner(10),
				Gradient = if tab == "Boosts" then gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 56, 86)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 34, 52)),
				}, 135) else gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 30, 42)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 20, 30)),
				}, 135),
			}),
		}),

		Items = e("ScrollingFrame", {
			BackgroundColor3 = Color3.fromRGB(10, 15, 23),
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 620),
			Position = UDim2.fromOffset(26, if tab == "Boosts" then 178 else 156),
			ScrollBarImageColor3 = tabAccent,
			ScrollBarThickness = 4,
			Size = UDim2.fromOffset(506, if tab == "Boosts" then 296 else 318),
			Visible = true,
		}, {
			Corner = corner(16),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1,
				Transparency = 0.36,
			}),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 20, 30)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 10, 16)),
			}, 180),
			Grid = e("UIGridLayout", {
				CellPadding = UDim2.fromOffset(14, 14),
				CellSize = UDim2.fromOffset(142, 136),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 16),
			}),
			Items = React.createElement(React.Fragment, nil, gridChildren),
		}),

		ItemInfo = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(11, 16, 25),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(548, 88),
			Size = UDim2.fromOffset(108, 386),
			Visible = selectedItem ~= nil,
		}, {
			Corner = corner(18),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1.5,
				Transparency = 0.28,
			}),
			Gradient = gradientRich({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 20, 30)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 14, 22)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 9, 16)),
			}, 135),
			Header = textLabel({
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(18, 18),
				Size = UDim2.fromOffset(72, 18),
				Text = if selectedItem then "Selected Item" else "Pick Something",
				TextColor3 = tabAccent,
				TextScaled = false,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Name = textLabel({
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(18, 44),
				Size = UDim2.fromOffset(74, 78),
				Text = if selectedItem then selectedItem.name else "Choose a product",
				TextColor3 = Color3.fromRGB(246, 249, 255),
				TextScaled = false,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Description = textLabel({
				Font = Enum.Font.GothamMedium,
				Position = UDim2.fromOffset(18, 132),
				Size = UDim2.fromOffset(74, 122),
				Text = itemDescription(selectedItem),
				TextColor3 = Color3.fromRGB(176, 188, 204),
				TextScaled = false,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			Notice = selectedItem and selectedItem.notice and textLabel({
				Font = Enum.Font.GothamMedium,
				Position = UDim2.fromOffset(18, 260),
				Size = UDim2.fromOffset(74, 56),
				Text = selectedItem.notice,
				TextColor3 = Color3.fromRGB(255, 116, 130),
				TextScaled = false,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}) or nil,
			Purchase = solidButton({
				BackgroundColor3 = tabAccent,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(12, 326),
				Size = UDim2.fromOffset(84, 42),
				Text = if selectedItem then "Purchase" else "Select an item",
				TextColor3 = Color3.fromRGB(7, 11, 16),
				TextScaled = false,
				TextSize = 12,
				onActivated = function()
					if not selectedItem then
						return
					end

					local localPlayer = Players.LocalPlayer
					if selectedItem.productId then
						MarketplaceService:PromptProductPurchase(localPlayer, selectedItem.productId)
					elseif selectedItem.gamepassId then
						MarketplaceService:PromptGamePassPurchase(localPlayer, selectedItem.gamepassId)
					end
				end,
			}, {
				Corner = corner(14),
				Gradient = gradientRich({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 180)),
					ColorSequenceKeypoint.new(0.3, tabAccent),
					ColorSequenceKeypoint.new(1, tabAccent),
				}, 90),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255),
					Thickness = 1,
					Transparency = 0.56,
				}),
			}),
		}),

		BoostInfo = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(32, 150),
			Size = UDim2.fromOffset(520, 20),
			Text = "Boosts are only one-time use!",
			TextColor3 = Color3.fromRGB(116, 206, 255),
			TextScaled = false,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = tab == "Boosts",
		}),
	})
end


return ShopPanel
