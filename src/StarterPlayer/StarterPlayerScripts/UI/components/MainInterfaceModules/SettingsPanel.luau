local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local SettingsConfig = require(ReplicatedStorage.Modules.SettingsManager.SettingsConfig)
local SettingsUpdater = require(ReplicatedStorage.Modules.SettingsManager.SettingsUpdater)
local InterfaceKit = require(script.Parent.InterfaceKit)

local e = React.createElement
local textLabel = InterfaceKit.TextLabel
local solidButton = InterfaceKit.SolidButton
local useTweenNumber = InterfaceKit.UseTweenNumber

local function round(radius: number)
	return e("UICorner", {
		CornerRadius = UDim.new(0, radius),
	})
end

local function stroke(color: Color3, transparency: number?, thickness: number?)
	return e("UIStroke", {
		Color = color,
		Transparency = transparency or 0.5,
		Thickness = thickness or 1,
	})
end

local function cloneDefaults(): { [string]: any }
	return table.clone(SettingsConfig.default_settings)
end

local function mergeSettings(rawSettings: any): { [string]: any }
	local merged = cloneDefaults()
	if type(rawSettings) ~= "table" then
		return merged
	end

	for key, value in rawSettings do
		if merged[key] ~= nil then
			merged[key] = value
		end
	end

	return merged
end

local function applyAll(settings: { [string]: any })
	for name, value in settings do
		SettingsUpdater.ApplySetting(settings, name, value)
	end
end

local function saveSettings(settings: { [string]: any })
	task.spawn(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local exportRemote = remotes and remotes:FindFirstChild("ExportSettingsFunction")
		if exportRemote and exportRemote:IsA("RemoteFunction") then
			pcall(function()
				exportRemote:InvokeServer(settings)
			end)
		end
	end)
end

local function settingStep(component: { [string]: any }): number
	if component.step then
		return component.step
	end

	if component.max and component.max <= 1 then
		return 0.05
	end

	return 1
end

local function optionRow(props)
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 17, 25),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 74),
	}, {
		Corner = round(12),
		Stroke = stroke(Color3.fromRGB(91, 108, 132), 0.62, 1),
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(18, 12),
			Size = UDim2.new(1, -210, 0, 24),
			Text = props.name,
			TextColor3 = Color3.fromRGB(245, 247, 251),
			TextScaled = false,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Hint = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(18, 38),
			Size = UDim2.new(1, -210, 0, 18),
			Text = props.hint or "",
			TextColor3 = Color3.fromRGB(128, 144, 166),
			TextScaled = false,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Control = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -16, 0.5, 0),
			Size = UDim2.fromOffset(178, 46),
		}, props.children),
	})
end

local function booleanControl(value: boolean, onChange: (boolean) -> ())
	return solidButton({
		BackgroundColor3 = if value then Color3.fromRGB(32, 92, 65) else Color3.fromRGB(34, 38, 47),
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromOffset(122, 38),
		Text = if value then "ON" else "OFF",
		TextColor3 = if value then Color3.fromRGB(190, 255, 219) else Color3.fromRGB(210, 218, 230),
		TextScaled = false,
		TextSize = 15,
		onActivated = function()
			onChange(not value)
		end,
	}, {
		Corner = round(19),
		Stroke = stroke(if value then Color3.fromRGB(74, 222, 128) else Color3.fromRGB(148, 163, 184), 0.38, 1.5),
	})
end

local function rangeControl(value: number, component: { [string]: any }, onChange: (number) -> ())
	local minValue = component.min or 0
	local maxValue = component.max or 1
	local step = settingStep(component)
	local ratio = math.clamp((value - minValue) / math.max(maxValue - minValue, 1e-6), 0, 1)
	local display = if maxValue <= 1 then `{math.round(value * 100)}%` else tostring(math.round(value))

	return e(React.Fragment, nil, {
		Bar = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(35, 43, 55),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.fromOffset(176, 8),
		}, {
			Corner = round(4),
			Fill = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 177, 78),
				BorderSizePixel = 0,
				Size = UDim2.new(ratio, 0, 1, 0),
			}, {
				Corner = round(4),
			}),
		}),
		Minus = solidButton({
			BackgroundColor3 = Color3.fromRGB(19, 25, 34),
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(34, 24),
			Text = "-",
			TextColor3 = Color3.fromRGB(245, 247, 251),
			TextScaled = false,
			TextSize = 18,
			onActivated = function()
				onChange(math.clamp(value - step, minValue, maxValue))
			end,
		}, { Corner = round(8) }),
		Value = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.fromOffset(96, 24),
			Text = display,
			TextColor3 = Color3.fromRGB(255, 238, 207),
			TextScaled = false,
			TextSize = 14,
		}),
		Plus = solidButton({
			BackgroundColor3 = Color3.fromRGB(19, 25, 34),
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(142, 0),
			Size = UDim2.fromOffset(34, 24),
			Text = "+",
			TextColor3 = Color3.fromRGB(245, 247, 251),
			TextScaled = false,
			TextSize = 18,
			onActivated = function()
				onChange(math.clamp(value + step, minValue, maxValue))
			end,
		}, { Corner = round(8) }),
	})
end

local function choiceControl(value: string, choices: { string }, onChange: (string) -> ())
	local children = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, choice in ipairs(choices) do
		local selected = choice == value
		children[`Choice{index}`] = solidButton({
			BackgroundColor3 = if selected then Color3.fromRGB(255, 177, 78) else Color3.fromRGB(23, 29, 39),
			Font = Enum.Font.GothamBold,
			LayoutOrder = index,
			Size = UDim2.fromOffset(52, 38),
			Text = choice,
			TextColor3 = if selected then Color3.fromRGB(20, 14, 9) else Color3.fromRGB(213, 221, 234),
			TextScaled = false,
			TextSize = 10,
			onActivated = function()
				onChange(choice)
			end,
		}, {
			Corner = round(9),
			Stroke = stroke(if selected then Color3.fromRGB(255, 218, 148) else Color3.fromRGB(93, 108, 132), 0.45, 1),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(178, 38),
	}, children)
end

local function SettingsPanel(props)
	local appear = useTweenNumber(if props.visible then 1 else 0, 0.42, "OutBack")
	local firstTab = SettingsConfig.default_settings_tab or (SettingsConfig.settings_tabs[1] and SettingsConfig.settings_tabs[1].name) or "Gameplay"
	local activeTab, setActiveTab = React.useState(firstTab)
	local settings, setSettings = React.useState(cloneDefaults())

	React.useEffect(function()
		local cancelled = false
		task.spawn(function()
			local loaded = cloneDefaults()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local getRemote = remotes and remotes:FindFirstChild("GetSettingsData")
			if getRemote and getRemote:IsA("RemoteFunction") then
				local ok, success, data = pcall(function()
					return getRemote:InvokeServer()
				end)
				if ok and success == true then
					loaded = mergeSettings(data)
				end
			end

			if not cancelled then
				setSettings(loaded)
				applyAll(loaded)
			end
		end)

		return function()
			cancelled = true
		end
	end, {})

	local function updateSetting(name: string, value: any)
		local nextSettings = table.clone(settings)
		nextSettings[name] = value
		setSettings(nextSettings)
		SettingsUpdater.ApplySetting(nextSettings, name, value)
		saveSettings(nextSettings)
	end

	local tabButtons = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, tab in ipairs(SettingsConfig.settings_tabs) do
		local selected = tab.name == activeTab
		tabButtons[`Tab{index}`] = solidButton({
			BackgroundColor3 = if selected then Color3.fromRGB(255, 177, 78) else Color3.fromRGB(15, 20, 29),
			Font = Enum.Font.GothamBold,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 42),
			Text = tab.name,
			TextColor3 = if selected then Color3.fromRGB(20, 14, 9) else Color3.fromRGB(224, 231, 242),
			TextScaled = false,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			onActivated = function()
				setActiveTab(tab.name)
			end,
		}, {
			Corner = round(10),
			Stroke = stroke(if selected then Color3.fromRGB(255, 218, 148) else Color3.fromRGB(82, 95, 118), 0.48, 1),
			Pad = e("UIPadding", {
				PaddingLeft = UDim.new(0, 14),
			}),
		})
	end

	local optionChildren = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, option in ipairs(SettingsConfig.settings_options[activeTab] or {}) do
		local component = option.component or {}
		local value = settings[option.name]
		local control
		if component.class == "boolean" then
			control = booleanControl(value == true, function(nextValue)
				updateSetting(option.name, nextValue)
			end)
		elseif component.class == "range" then
			control = rangeControl(tonumber(value) or component.default or 0, component, function(nextValue)
				updateSetting(option.name, nextValue)
			end)
		elseif component.class == "choice" then
			control = choiceControl(tostring(value or component.default), component.choices or {}, function(nextValue)
				updateSetting(option.name, nextValue)
			end)
		else
			control = textLabel({ Text = "Unsupported", TextColor3 = Color3.fromRGB(255, 120, 120) })
		end

		optionChildren[`Option{index}`] = e(optionRow, {
			LayoutOrder = index,
			name = option.name,
			hint = component.class == "boolean" and "Toggle this behavior instantly." or "Adjust and save automatically.",
		}, {
			Control = control,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(7, 10, 16),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(760, 460),
		Visible = props.visible or appear > 0.02,
	}, {
		Scale = e("UIScale", {
			Scale = (props.uiScale or 1) * (0.88 + appear * 0.12),
		}),
		Corner = round(18),
		Stroke = stroke(Color3.fromRGB(255, 255, 255), 0.72, 1),
		Title = textLabel({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(28, 22),
			Size = UDim2.fromOffset(260, 36),
			Text = "Settings",
			TextColor3 = Color3.fromRGB(249, 251, 255),
			TextScaled = false,
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Subtitle = textLabel({
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(30, 58),
			Size = UDim2.fromOffset(340, 20),
			Text = "Gameplay, graphics, and audio preferences",
			TextColor3 = Color3.fromRGB(142, 157, 178),
			TextScaled = false,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Close = solidButton({
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromRGB(36, 18, 24),
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -22, 0, 22),
			Size = UDim2.fromOffset(42, 42),
			Text = "X",
			TextColor3 = Color3.fromRGB(255, 226, 232),
			TextScaled = false,
			TextSize = 18,
			onActivated = props.close,
		}, {
			Corner = round(12),
			Stroke = stroke(Color3.fromRGB(255, 93, 112), 0.48, 1),
		}),
		Tabs = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(28, 106),
			Size = UDim2.fromOffset(172, 310),
		}, tabButtons),
		Options = e("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			Position = UDim2.fromOffset(226, 104),
			ScrollBarImageColor3 = Color3.fromRGB(255, 177, 78),
			ScrollBarThickness = 5,
			Size = UDim2.fromOffset(500, 318),
		}, optionChildren),
	})
end

return SettingsPanel