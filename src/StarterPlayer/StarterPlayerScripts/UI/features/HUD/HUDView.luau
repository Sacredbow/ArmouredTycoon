


-- This will in the future be the replacement of the Shop gui (the gui isnatnces we reference in the StarterGUI




-- --!strict

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local React = require(ReplicatedStorage.Packages.react)

-- local StatPill = require(script.Parent.components.StatPill)
-- local Theme = require(script.Parent.Parent.Parent.shared.Theme)
-- local useSpringBinding = require(script.Parent.Parent.Parent.hooks.useSpringBinding)

-- local e = React.createElement

-- local function selectStats(snapshot)
-- 	return snapshot.stats
-- end

-- local function HUD(props)
-- 	props = props or {}

-- 	local stats = props.stats
-- 	if not stats then
-- 		local useGameStore = require(script.Parent.Parent.Parent.store.useGameStore)
-- 		stats = useGameStore(selectStats)
-- 	end

-- 	local intro = useSpringBinding(1, 13, 0)

-- 	return e("CanvasGroup", {
-- 		BackgroundTransparency = 1,
-- 		GroupTransparency = intro:map(function(value)
-- 			return 1 - value
-- 		end),
-- 		Position = intro:map(function(value)
-- 			return UDim2.fromOffset(18, 18 + (1 - value) * 10)
-- 		end),
-- 		Size = UDim2.fromOffset(350, 108),
-- 	}, {
-- 		Scale = e("UIScale", {
-- 			Scale = 1,
-- 		}),

-- 		Grid = e("UIGridLayout", {
-- 			CellPadding = UDim2.fromOffset(10, 10),
-- 			CellSize = UDim2.fromOffset(164, 48),
-- 			FillDirectionMaxCells = 2,
-- 			SortOrder = Enum.SortOrder.LayoutOrder,
-- 		}),

-- 		Cash = e(StatPill, {
-- 			label = "Cash",
-- 			value = stats.Cash,
-- 			accent = Theme.Colors.Cash,
-- 			currency = true,
-- 			LayoutOrder = 1,
-- 		}),

-- 		Emerald = e(StatPill, {
-- 			label = "Emerald",
-- 			value = stats.Emerald,
-- 			accent = Theme.Colors.Emerald,
-- 			LayoutOrder = 2,
-- 		}),

-- 		Kills = e(StatPill, {
-- 			label = "Kills",
-- 			value = stats.Kills,
-- 			accent = Theme.Colors.Kills,
-- 			LayoutOrder = 3,
-- 		}),

-- 		Rebirths = e(StatPill, {
-- 			label = "Rebirths",
-- 			value = stats.Rebirths,
-- 			accent = Theme.Colors.Rebirths,
-- 			LayoutOrder = 4,
-- 		}),
-- 	})
-- end

-- return HUD
