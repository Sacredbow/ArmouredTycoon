--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.react)

local Theme = require(script.Parent.Parent.theme.Theme)
local useSpringBinding = require(script.Parent.Parent.hooks.useSpringBinding)

local e = React.createElement

local function selectConversation(snapshot)
	return snapshot.npcConversation
end

local function NPCConversationPanel(props)
	props = props or {}

	local conversation = props.conversation
	local store = props.store
	if not conversation then
		local useGameStore = require(script.Parent.Parent.store.useGameStore)
		local GameStore = require(script.Parent.Parent.store.GameStore)
		conversation = useGameStore(selectConversation)
		store = store or GameStore.get()
	end

	local visible = conversation ~= nil
	local progress = useSpringBinding(if visible then 1 else 0, 15, 0)
	local viewportSize, setViewportSize = React.useState(function()
		local camera = Workspace.CurrentCamera
		return if camera then camera.ViewportSize else Vector2.new(1280, 720)
	end)

	React.useEffect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return nil
		end

		setViewportSize(camera.ViewportSize)
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setViewportSize(camera.ViewportSize)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	if not conversation then
		return nil
	end

	local panelScale = math.clamp((viewportSize.X - 28) / 600, 0.58, 1)
	local optionChildren = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, option in ipairs(conversation.options) do
		if index > 3 then
			break
		end

		optionChildren[`Option{index}`] = e("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = Color3.fromRGB(6, 8, 11),
			Font = Theme.Fonts.Body,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 46),
			Text = option.text,
			TextColor3 = Color3.fromRGB(244, 247, 250),
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.None,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			[React.Event.Activated] = function()
				if store and store.ChooseNPCConversationOption then
					store:ChooseNPCConversationOption(option.id)
				end
			end,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 7),
			}),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(245, 248, 252),
				Thickness = 1,
				Transparency = 0.18,
			}),
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
		})
	end

	local children = {
		Scale = e("UIScale", {
			Scale = panelScale,
		}),

		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),

		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(238, 243, 248),
			Thickness = 1,
			Transparency = 0.16,
		}),

		Gradient = e("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 25, 31)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 7, 10)),
			}),
			Rotation = 90,
		}),

		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}),

		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, -56, 0, 22),
			Text = conversation.npcName,
			TextColor3 = Color3.fromRGB(246, 249, 252),
			TextSize = 18,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Counter = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Body,
			Position = UDim2.new(1, -52, 0, 2),
			Size = UDim2.fromOffset(52, 18),
			Text = `{conversation.turnCount}/{conversation.maxTurns}`,
			TextColor3 = Color3.fromRGB(178, 188, 198),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),

		Line = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Body,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 44),
			Text = conversation.npcLine,
			TextColor3 = Color3.fromRGB(229, 235, 241),
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),

		Options = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 86),
			Size = UDim2.new(1, 0, 0, 150),
		}, optionChildren),
	}

	return e("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.Colors.Panel,
		GroupTransparency = progress:map(function(value)
			return 1 - value
		end),
		Position = progress:map(function(value)
			return UDim2.new(0.5, 0, 1, -36 - (1 - value) * -18)
		end),
		Size = UDim2.fromOffset(600, 272),
	}, children)
end

return NPCConversationPanel
