--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.react)

local InventoryController = require(script.Parent.Parent.Parent.Parent.InventoryClient.Controller)
local InventoryShared = require(ReplicatedStorage.CharacterUtilities.Inventory.InventoryShared)
local Theme = require(script.Parent.Parent.Parent.theme.Theme)
local useSpringBinding = require(script.Parent.Parent.Parent.hooks.useSpringBinding)

local e = React.createElement

local WHEEL_TEXTURE = "rbxthumb://type=Asset&id=76873664868429&w=420&h=420"
local BACKPACK_ICON_TEXT = '<font family="rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json">backpack</font>'
local WHEEL_SIZE = 860
local SLOT_WIDTH = 310
local SLOT_HEIGHT = 195
local SLOT_RADIUS = 190
local CENTER_SIZE = 250
local ROOT_WIDTH = 1380
local ROOT_HEIGHT = 780
local TOPBAR_BUTTON_POSITION = UDim2.fromOffset(250, 13)
local TOPBAR_BUTTON_SIZE = UDim2.fromOffset(47, 47)
local WHEEL_CENTER_SCALE = Vector2.new(0.39, 0.5)
local STAT_ORDER = { "Damage", "Fire Rate", "Accuracy", "Capacity" }
local inventoryHintSeen = true

local function useInventory(previewSnapshot, previewController)
	if previewSnapshot and previewController then
		return previewSnapshot, previewController
	end

	local controller = InventoryController.get()
	controller:Start()

	local snapshot, setSnapshot = React.useState(function()
		return controller:GetSnapshot()
	end)

	React.useEffect(function()
		local function update()
			setSnapshot(controller:GetSnapshot())
		end

		update()
		return controller:Subscribe(update)
	end, { controller })

	return snapshot, controller
end

local function getItemForSlot(items: { InventoryShared.InventoryItem }, slot: number): InventoryShared.InventoryItem?
	for _, item in ipairs(items) do
		if item.slot == slot then
			return item
		end
	end

	return nil
end

local function StatBar(props)
	local name: string = props.name
	local value: number = props.value or 0
	local index: number = props.index or 1
	local response = math.clamp(2.8 + math.min(value, 260) / 20 + index * 0.45, 3.2, 18)
	local fill = useSpringBinding(math.clamp(value, 0, 100) / 100, response, 0)
	local number = useSpringBinding(value, response, 0)

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 42),
	}, {
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Body,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, -58, 0, 17),
			Text = string.upper(name),
			TextColor3 = Color3.fromRGB(202, 209, 218),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Position = UDim2.new(1, -56, 0, -1),
			Size = UDim2.fromOffset(56, 18),
			Text = number:map(function(animated)
				return tostring(math.floor(animated + 0.5))
			end),
			TextColor3 = Color3.fromRGB(248, 250, 253),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Track = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(44, 49, 57),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 23),
			Size = UDim2.new(1, 0, 0, 9),
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 5),
			}),
			Fill = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(246, 248, 252),
				BorderSizePixel = 0,
				Size = fill:map(function(animated)
					return UDim2.new(animated, 0, 1, 0)
				end),
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 5),
				}),
			}),
		}),
	})
end

local function WheelSlot(props)
	local slot: number = props.slot
	local item: InventoryShared.InventoryItem? = props.item
	local selected: boolean = props.selected
	local hovered: boolean = props.hovered
	local openProgress = props.openProgress
	local angle = math.rad((slot - 1) * 45 - 90)
	local x = math.cos(angle) * SLOT_RADIUS
	local y = math.sin(angle) * SLOT_RADIUS
	local active = selected or hovered
	local color = if active then Color3.fromRGB(74, 170, 255) else Color3.fromRGB(236, 239, 244)
	local transparency = if active then 0 elseif item then 0.05 else 0.26
	local slotDelay = (slot - 1) * 0.025
	local animatedPosition = if openProgress
		then openProgress:map(function(value)
			local alpha = math.clamp((value - slotDelay) / (1 - slotDelay), 0, 1)
			local eased = 1 - (1 - alpha) ^ 5
			local radiusScale = 0.5 + eased * 0.5
			return UDim2.new(0.5, x * radiusScale, 0.5, y * radiusScale)
		end)
		else UDim2.new(0.5, x, 0.5, y)
	local animatedSize = if openProgress
		then openProgress:map(function(value)
			local alpha = math.clamp((value - slotDelay) / (1 - slotDelay), 0, 1)
			local eased = 1 - (1 - alpha) ^ 5
			local sizeScale = 0.5 + eased * 0.5
			return UDim2.fromOffset(SLOT_WIDTH * sizeScale, SLOT_HEIGHT * sizeScale)
		end)
		else UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT)
	local animatedTransparency = if openProgress
		then openProgress:map(function(value)
			local alpha = math.clamp((value - slotDelay) / (1 - slotDelay), 0, 1)
			local eased = 1 - (1 - alpha) ^ 2
			return 1 - (1 - transparency) * eased
		end)
		else transparency

	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = WHEEL_TEXTURE,
		ImageColor3 = color,
		ImageTransparency = animatedTransparency,
		Position = animatedPosition,
		Rotation = math.deg(angle) + 90,
		ScaleType = Enum.ScaleType.Stretch,
		Size = animatedSize,
		ZIndex = if active then 8 else 4,
	}, {
		SlotNumber = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Position = UDim2.fromScale(0.16, 0.16),
			Rotation = -math.deg(angle) - 90,
			Size = UDim2.fromOffset(30, 22),
			Text = tostring(slot),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 19,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.04,
			ZIndex = 12,
		}),
		Icon = item and item.icon and e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = item.icon,
			ImageColor3 = if active then Color3.fromRGB(178, 224, 255) else Color3.fromRGB(245, 248, 252),
			Position = UDim2.fromScale(0.5, 0.48),
			Rotation = -math.deg(angle) - 90,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(154, 78),
			ZIndex = 10,
		}),
		Empty = not item and e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Body,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = -math.deg(angle) - 90,
			Size = UDim2.new(1, -24, 0, 18),
			Text = "EMPTY",
			TextColor3 = Color3.fromRGB(184, 190, 199),
			TextTransparency = 0.38,
			TextSize = 12,
			ZIndex = 10,
		}),
	})
end

local function ActionButton(props)
	local disabled = props.disabled == true
	local variant = props.variant or "primary"
	local isDanger = variant == "danger"
	local isGhost = variant == "ghost"

	return e("TextButton", {
		AutoButtonColor = not disabled,
		BackgroundColor3 = if disabled
			then Color3.fromRGB(18, 20, 24)
			elseif isDanger
			then Color3.fromRGB(255, 95, 85)
			elseif isGhost
			then Color3.fromRGB(24, 28, 35)
			else Color3.fromRGB(246, 248, 252),
		BackgroundTransparency = if disabled then 0.38 else 0,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		Size = UDim2.fromOffset(props.width or 98, props.height or 30),
		Text = `{props.keyText}  {props.label}`,
		TextColor3 = if disabled
			then Color3.fromRGB(116, 124, 136)
			elseif isGhost
			then Color3.fromRGB(238, 242, 248)
			else Color3.fromRGB(12, 14, 18),
		TextSize = props.textSize or 12,
		Font = Theme.Fonts.Display,
		[React.Event.Activated] = function()
			if not disabled and props.onActivated then
				props.onActivated()
			end
		end,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		Stroke = if isGhost then e("UIStroke", {
			Color = Color3.fromRGB(238, 242, 248),
			Thickness = 1,
			Transparency = if disabled then 0.72 else 0.2,
		}) else nil,
	})
end

local function InventoryTopbarButton(props)
	local controller = props.controller
	local showHint: boolean = props.showHint == true
	local dismissHint = props.dismissHint
	local isOpen: boolean = props.isOpen == true
	local openProgress = props.openProgress
	local pulse = useSpringBinding(if showHint then 1 else 0, 8, 0)
	local buttonBackground = if openProgress
		then openProgress:map(function(value)
			return if value > 0.03 then Color3.fromRGB(40, 116, 190) else Color3.fromRGB(12, 14, 18)
		end)
		else if isOpen then Color3.fromRGB(40, 116, 190) else Color3.fromRGB(12, 14, 18)
	local strokeTransparency = if openProgress
		then openProgress:map(function(value)
			return if value > 0.03 or showHint then 0.05 else 0.48
		end)
		else if isOpen or showHint then 0.05 else 0.48

	return e(React.Fragment, nil, {
		HintShade = showHint and e("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.34,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 300,
			[React.Event.Activated] = dismissHint,
		}, {
			Callout = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.96,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(142, 5),
				Size = UDim2.fromOffset(58, 58),
				ZIndex = 301,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 10),
				}),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255),
					Thickness = pulse:map(function(value)
						return 2 + value * 2
					end),
					Transparency = 0.02,
				}),
			}),
			Label = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(8, 10, 13),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(208, 13),
				Size = UDim2.fromOffset(246, 42),
				ZIndex = 301,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255),
					Thickness = 1,
					Transparency = 0.28,
				}),
				Text = e("TextLabel", {
					BackgroundTransparency = 1,
					Font = Theme.Fonts.Display,
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -24, 1, 0),
					Text = "Inventory is here",
					TextColor3 = Color3.fromRGB(248, 250, 253),
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 302,
				}),
			}),
		}),
		Button = e("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = buttonBackground,
			BorderSizePixel = 0,

			Position = TOPBAR_BUTTON_POSITION,
			RichText = true,
			Size = TOPBAR_BUTTON_SIZE,
			Text = BACKPACK_ICON_TEXT,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = false,
			TextSize = 25,
			ZIndex = if showHint then 330 else 80,
			[React.Event.Activated] = function()
				if showHint then
					dismissHint()
				end

				controller:SetOpen(not isOpen)
			end,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 10),
			}),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = if showHint then 2 else 1,
				Transparency = strokeTransparency,
			}),
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 7),
				PaddingBottom = UDim.new(0, 7),
				PaddingLeft = UDim.new(0, 7),
				PaddingRight = UDim.new(0, 7),
			}),
		}),
	})
end

local function StatPanel(props)
	local item: InventoryShared.InventoryItem? = props.item
	local controller = props.controller
	local openRemoveConfirm = props.openRemoveConfirm
	local stats = if item and item.stats then item.stats else {}
	local statChildren = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, statName in ipairs(STAT_ORDER) do
		statChildren[statName] = e(StatBar, {
			index = index,
			name = statName,
			value = stats[statName] or 0,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 10, 13),
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -132, 0.5, 0),
		Size = UDim2.fromOffset(318, 460),
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(238, 241, 246),
			Thickness = 1,
			Transparency = 0.04,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Size = UDim2.new(1, 0, 0, 30),
			Text = if item then string.upper(item.name) else "NO WEAPON",
			TextColor3 = if item then Color3.fromRGB(250, 252, 255) else Color3.fromRGB(140, 148, 160),
			TextSize = 22,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Meta = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Body,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 22),
			Text = if item then `{item.category} / {item.rarity}` else "Hover over a weapon",
			TextColor3 = if item then item.accent else Color3.fromRGB(132, 141, 154),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Stats = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 78),
			Size = UDim2.new(1, 0, 0, 195),
		}, statChildren),
		Slot = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Body,
			Position = UDim2.fromOffset(0, 288),
			Size = UDim2.new(1, 0, 0, 24),
			Text = if item then `SLOT {item.slot or 0}     QTY {item.quantity}` else "SLOT EMPTY",
			TextColor3 = Color3.fromRGB(198, 206, 216),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Actions = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 1, -74),
			Size = UDim2.new(1, 0, 0, 68),
		}, {
			Equip = e(ActionButton, {
				disabled = item == nil,
				height = 30,
				keyText = "E",
				label = "Equip",
				layoutOrder = 1,
				position = UDim2.fromOffset(0, 0),
				width = 104,
				onActivated = function()
					controller:EquipSelected()
				end,
			}),
			Remove = e(ActionButton, {
				disabled = item == nil,
				anchorPoint = Vector2.new(1, 0),
				height = 30,
				keyText = "R",
				label = "Remove",
				layoutOrder = 2,
				position = UDim2.new(1, 0, 0, 0),
				variant = "danger",
				width = 104,
				onActivated = openRemoveConfirm,
			}),
			Unequip = e(ActionButton, {
				anchorPoint = Vector2.new(0.5, 0),
				disabled = item == nil or item.equipped ~= true,
				height = 30,
				keyText = "U",
				label = "Unequip",
				layoutOrder = 3,
				position = UDim2.new(0.5, 0, 0, 38),
				variant = "ghost",
				width = 132,
				onActivated = function()
					controller:UnequipSelected()
				end,
			}),
		}),
	})
end

local function ConfirmRemoveOverlay(props)
	local selectedItem = props.selectedItem
	if not selectedItem then
		return nil
	end

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 200,
	}, {
		Dialog = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(8, 10, 13),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(390, 158),
			ZIndex = 201,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 92, 82),
				Thickness = 1,
			}),
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Display,
				Position = UDim2.fromOffset(22, 18),
				Size = UDim2.new(1, -44, 0, 25),
				Text = "REMOVE WEAPON?",
				TextColor3 = Color3.fromRGB(255, 245, 244),
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 202,
			}),
			Body = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Body,
				Position = UDim2.fromOffset(22, 52),
				Size = UDim2.new(1, -44, 0, 36),
				Text = `Remove {selectedItem.name} from your inventory?`,
				TextColor3 = Color3.fromRGB(214, 221, 230),
				TextSize = 14,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 202,
			}),
			Cancel = e("TextButton", {
				BackgroundColor3 = Color3.fromRGB(34, 39, 48),
				BorderSizePixel = 0,
				Font = Theme.Fonts.Display,
				Position = UDim2.new(0, 22, 1, -46),
				Size = UDim2.fromOffset(130, 30),
				Text = "Cancel",
				TextColor3 = Color3.fromRGB(240, 244, 248),
				TextSize = 13,
				ZIndex = 202,
				[React.Event.Activated] = props.onCancel,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 5),
				}),
			}),
			Confirm = e("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(255, 92, 82),
				BorderSizePixel = 0,
				Font = Theme.Fonts.Display,
				Position = UDim2.new(1, -22, 1, -46),
				Size = UDim2.fromOffset(130, 30),
				Text = "Remove",
				TextColor3 = Color3.fromRGB(18, 8, 8),
				TextSize = 13,
				ZIndex = 202,
				[React.Event.Activated] = props.onConfirm,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 5),
				}),
			}),
		}),
	})
end

local function InventoryPanel(props)
	props = props or {}

	local snapshot, controller = useInventory(props.previewSnapshot, props.previewController)
	local progress = useSpringBinding(if snapshot.isOpen then 1 else 0, 14, 0)
	local selectedItem = getItemForSlot(snapshot.items, snapshot.selectedSlot)
	local confirmRemove, setConfirmRemove = React.useState(false)
	local showInventoryHint, setShowInventoryHint = React.useState(false)
	local viewportSize, setViewportSize = React.useState(function()
		local camera = Workspace.CurrentCamera
		return if camera then camera.ViewportSize else Vector2.new(1280, 720)
	end)
	local scale = math.clamp(math.min(viewportSize.X / ROOT_WIDTH, viewportSize.Y / ROOT_HEIGHT), 0.42, 1.05)

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

	local function openRemoveConfirm()
		if selectedItem then
			setConfirmRemove(true)
		end
	end

	local function closeRemoveConfirm()
		setConfirmRemove(false)
	end

	local function confirmRemoveSelected()
		controller:RemoveSelected()
		setConfirmRemove(false)
	end

	local function dismissInventoryHint()
		inventoryHintSeen = true
		setShowInventoryHint(false)
	end

	React.useEffect(function()
		if not snapshot.isOpen then
			setConfirmRemove(false)
		end
	end, { snapshot.isOpen })

	React.useEffect(function()
		if inventoryHintSeen then
			return
		end

		if #snapshot.items > 0 then
			setShowInventoryHint(true)
		end
	end, { #snapshot.items })

	React.useEffect(function()
		if snapshot.isOpen and showInventoryHint then
			dismissInventoryHint()
		end
	end, { snapshot.isOpen, showInventoryHint })

	React.useEffect(function()
		local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not snapshot.isOpen then
				return
			end

			if input.KeyCode == Enum.KeyCode.R then
				if confirmRemove then
					confirmRemoveSelected()
				else
					openRemoveConfirm()
				end
			elseif input.KeyCode == Enum.KeyCode.U then
				controller:UnequipSelected()
			elseif input.KeyCode == Enum.KeyCode.Escape and confirmRemove then
				closeRemoveConfirm()
			end

			if gameProcessed then
				return
			end
		end)

		return function()
			inputConnection:Disconnect()
		end
	end, { snapshot.isOpen, snapshot.selectedSlot, confirmRemove, selectedItem })

	local slots = {}
	for slot = 1, snapshot.maxSlots do
		slots[`Slot{slot}`] = e(WheelSlot, {
			hovered = false,
			item = getItemForSlot(snapshot.items, slot),
			openProgress = progress,
			selected = snapshot.selectedSlot == slot,
			slot = slot,
		})
	end

	local mobileSlotButtons = {}
	if UserInputService.TouchEnabled then
		for slot = 1, snapshot.maxSlots do
			local isSelected = snapshot.selectedSlot == slot
			mobileSlotButtons[`MobileSlot{slot}`] = e("TextButton", {
				AutoButtonColor = true,
				BackgroundColor3 = if isSelected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(9, 11, 15),
				BackgroundTransparency = if isSelected then 0.02 else 0.16,
				BorderSizePixel = 0,
				Font = Theme.Fonts.Display,
				LayoutOrder = slot,
				Size = UDim2.fromOffset(42, 42),
				Text = tostring(slot),
				TextColor3 = if isSelected then Color3.fromRGB(10, 12, 16) else Color3.fromRGB(244, 247, 252),
				TextSize = 18,
				ZIndex = 65,
				[React.Event.Activated] = function()
					controller:SelectSlot(slot)
				end,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 7),
				}),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255),
					Thickness = 1,
					Transparency = if isSelected then 0.1 else 0.55,
				}),
			})
		end
	end

	return e(React.Fragment, nil, {
		TopbarInventory = e(InventoryTopbarButton, {
			controller = controller,
			dismissHint = dismissInventoryHint,
			isOpen = snapshot.isOpen,
			openProgress = progress,
			showHint = showInventoryHint,
		}),
		Inventory = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 1),
			Visible = progress:map(function(value)
				return value > 0.01
			end),
		}, {
			Shade = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}),
			Root = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(ROOT_WIDTH, ROOT_HEIGHT),
			}, {
				Aspect = e("UIAspectRatioConstraint", {
					AspectRatio = ROOT_WIDTH / ROOT_HEIGHT,
					DominantAxis = Enum.DominantAxis.Width,
				}),
				Scale = e("UIScale", {
					Scale = scale,
				}),
				Wheel = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(WHEEL_CENTER_SCALE.X, WHEEL_CENTER_SCALE.Y),
					Size = UDim2.fromOffset(WHEEL_SIZE, WHEEL_SIZE),
				}, {
					Aspect = e("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
					Center = e("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(8, 10, 13),
						BackgroundTransparency = 0.04,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(CENTER_SIZE, CENTER_SIZE),
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
						Stroke = e("UIStroke", {
							Color = Color3.fromRGB(238, 242, 248),
							Thickness = 1,
							Transparency = 0.28,
						}),
						Text = e("TextLabel", {
							BackgroundTransparency = 1,
							Font = Theme.Fonts.Display,
							Position = UDim2.fromScale(0.08, 0.33),
							Size = UDim2.fromScale(0.84, 0.34),
							Text = if selectedItem then string.upper(selectedItem.name) else "SELECT",
							TextColor3 = Color3.fromRGB(245, 248, 252),
							TextScaled = true,
							TextTruncate = Enum.TextTruncate.AtEnd,
						}, {
							Limit = e("UITextSizeConstraint", {
								MaxTextSize = 22,
								MinTextSize = 9,
							}),
						}),
					}),
					Slots = e(React.Fragment, nil, slots),
				}),
				MobileSlots = UserInputService.TouchEnabled and e("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = Color3.fromRGB(0, 0, 0),
					BackgroundTransparency = 0.42,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(WHEEL_CENTER_SCALE.X, 0.965),
					Size = UDim2.fromOffset(396, 52),
					ZIndex = 64,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 9),
					}),
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					Padding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
					Buttons = e(React.Fragment, nil, mobileSlotButtons),
				}),
				Stats = e(StatPanel, {
					controller = controller,
					item = selectedItem,
					openRemoveConfirm = openRemoveConfirm,
				}),
			}),
		}),
		ConfirmRemove = confirmRemove and e(ConfirmRemoveOverlay, {
			selectedItem = selectedItem,
			onCancel = closeRemoveConfirm,
			onConfirm = confirmRemoveSelected,
		}),
	})
end

return InventoryPanel
