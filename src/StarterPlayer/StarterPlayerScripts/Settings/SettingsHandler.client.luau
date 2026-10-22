
repeat task.wait() 
until game:IsLoaded()
-- NewSettingsHandler - handles all option interactions for the NewSettings GUI
-- Services
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")

-- Remotes
local remotesFolder = replicatedStorage:WaitForChild("Remotes")
local getDataRemote = remotesFolder:WaitForChild("GetSettingsData")
local exportRemote = remotesFolder:WaitForChild("ExportSettingsFunction")

-- Modules
local modulesFolder = replicatedStorage:WaitForChild("Modules")
local SettingsConfig = require(modulesFolder:WaitForChild("SettingsManager"):WaitForChild("SettingsConfig"))
local SettingsUpdater = require(modulesFolder:WaitForChild("SettingsManager"):WaitForChild("SettingsUpdater"))
local PlaySound = require(modulesFolder:WaitForChild("PlaySound"))
local AnimationController = require(script.Parent:WaitForChild("AnimationController"))

-- Config
local defaultSettings = SettingsConfig.default_settings

-- Player
local localPlayer = playersService.LocalPlayer

-- GUI references
local playerGui = localPlayer:WaitForChild("PlayerGui")
local newSettingsGui = playerGui:WaitForChild("NewSettings")
local settingsBg = newSettingsGui:WaitForChild("SettingsBackground")
local topBar = settingsBg:WaitForChild("TopBar")
local optionList = settingsBg:WaitForChild("OptionList")
local bottomBar = settingsBg:WaitForChild("BottomBar")
local resetFrame = settingsBg:WaitForChild("Reset")
local sectionHandler = settingsBg:WaitForChild("SectionHandler")

-- Bottom bar buttons
local resetDefaultsBtn = bottomBar:WaitForChild("ResetDefaults")
local saveSettingsBtn = bottomBar:WaitForChild("SaveSettings")

-- Reset frame buttons
local yesBtn = resetFrame:WaitForChild("Yes")
local noBtn = resetFrame:WaitForChild("No")
local resetCloseBtn = resetFrame:WaitForChild("Close")

-- Visual constants
local TOGGLE_OFF_POS = UDim2.new(0, 0, 0.0826747343, 0)
local TOGGLE_ON_POS = UDim2.new(0, 44, 0.0826747343, 0)
local TOGGLE_ON_COLOR = Color3.fromRGB(255, 170, 0)
local TOGGLE_OFF_COLOR = Color3.fromRGB(15, 15, 15)

local CHOICE_SELECTED_BG = Color3.fromRGB(255, 255, 255)
local CHOICE_SELECTED_TEXT = Color3.fromRGB(0, 0, 0)
local CHOICE_UNSELECTED_BG = Color3.fromRGB(15, 15, 15)
local CHOICE_UNSELECTED_TEXT = Color3.fromRGB(255, 255, 255)

-- Tab accent colors


local TAB_ACCENT_COLOR = Color3.fromRGB(255, 138, 0)
local TAB_DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

-- Settings name mapping (GUI label -> SettingsConfig key)
local settingsNameMap = {
	["SFX"] = "Mute SFX",
	['Enviornmental Volume'] = 'Environmental Volume',
}

-- Placeholder settings (visual only, not in SettingsConfig or type mismatch)
local placeholderSettings = {
	["Language"] = true,
	["Server Announcements"] = true,
	["Field of View"] = true,  -- Toggle in GUI but range in config
}

-- Choice value mapping (GUI button name -> config value)
local choiceValueMap = { ["Medium"] = "Normal" }
local choiceValueMapReverse = { ["Normal"] = "Medium" }

-- State
local userSettings = {}
local activeTab = "Audio"
local optionUpdaters = {}   -- settingsName -> function(value) updates visual + applies setting
local optionStates = {}      -- settingsName -> current value (for click handlers)

----------------------------------------------------------------
-- Helper functions
----------------------------------------------------------------

local function getConfigKey(settingsName)
	return settingsNameMap[settingsName] or settingsName
end

local function getOptionData(key)
	for _, tabOptions in pairs(SettingsConfig.settings_options) do
		for _, opt in ipairs(tabOptions) do
			if opt.name == key then
				return opt
			end
		end
	end
	return nil
end

local function applySetting(settingsName, value)
	local key = getConfigKey(settingsName)
	userSettings[key] = value
	if not placeholderSettings[settingsName] then
		SettingsUpdater.ApplySetting(userSettings, key, value)
	end
end

----------------------------------------------------------------
-- Settings loading
----------------------------------------------------------------

local function loadSettings()
	local ok, success, data = pcall(function()
		return getDataRemote:InvokeServer()
	end)
	if ok and success and type(data) == "table" then
		userSettings = table.clone(defaultSettings)
		for key, value in pairs(data) do
			if userSettings[key] ~= nil then
				userSettings[key] = value
			end
		end
	else
		userSettings = table.clone(defaultSettings)
	end

	-- Apply all settings to the game on load
	for name, value in pairs(userSettings) do
		SettingsUpdater.ApplySetting(userSettings, name, value)
	end
end

----------------------------------------------------------------
-- Toggle setup
----------------------------------------------------------------

local function animateToggle(toggle, isOn)
	local frame = toggle:FindFirstChild("Frame")
	if not frame then return end
	tweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Position = isOn and TOGGLE_ON_POS or TOGGLE_OFF_POS }):Play()
	tweenService:Create(toggle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ BackgroundColor3 = isOn and TOGGLE_ON_COLOR or TOGGLE_OFF_COLOR }):Play()
end

local function setupToggle(option, settingsName)
	local toggle = option:FindFirstChild("Toggle")
	if not toggle then return end

	local key = getConfigKey(settingsName)
	local isPlaceholder = placeholderSettings[settingsName] ~= nil
	local initialValue

	if not isPlaceholder then
		initialValue = userSettings[key]
		if initialValue == nil then initialValue = defaultSettings[key] end
	else
		initialValue = false
	end

	optionStates[settingsName] = initialValue

	-- Set initial visual
	local frame = toggle:FindFirstChild("Frame")
	if initialValue then
		frame.Position = TOGGLE_ON_POS
		toggle.BackgroundColor3 = TOGGLE_ON_COLOR
	else
		frame.Position = TOGGLE_OFF_POS
		toggle.BackgroundColor3 = TOGGLE_OFF_COLOR
	end

	-- Store updater for reset
	optionUpdaters[settingsName] = function(value)
		optionStates[settingsName] = value
		animateToggle(toggle, value)
		if not isPlaceholder then
			applySetting(settingsName, value)
		end
	end

	-- Click handler
	toggle.MouseEnter:Connect(function()
		PlaySound("Roblox GUI - Hover 01")
	end)
	toggle.Activated:Connect(function()
		PlaySound("Roblox_UI_Small_Click")
		local newVal = not optionStates[settingsName]
		optionUpdaters[settingsName](newVal)
	end)
end



local function setupSlider(option, settingsName)
	local leftBtn = option:FindFirstChild("LeftButton")
	local rightBtn = option:FindFirstChild("RightButton")
	local counter = option:FindFirstChild("Counter")
	if not leftBtn or not rightBtn or not counter then return end

	local key = getConfigKey(settingsName)
	local optionData = getOptionData(key)
	if not optionData then return end

	local comp = optionData.component
	local minVal, maxVal, suffix = comp.min or 0, comp.max or 1, comp.suffix
	local step = comp.step or (maxVal <= 1 and 0.05 or 1)

	local function updateDisplay(value)
		if suffix == "%" then
			counter.Text = tostring(math.floor(value * 100)) .. "%"
		else
			counter.Text = tostring(math.floor(value))
		end
	end

	local currentValue = userSettings[key] or comp.default
	optionStates[settingsName] = currentValue
	updateDisplay(currentValue)

	optionUpdaters[settingsName] = function(value)
		value = math.clamp(value, minVal, maxVal)
		optionStates[settingsName] = value
		updateDisplay(value)
		applySetting(settingsName, value)
	end

	local function changeValue(delta)
		PlaySound("Roblox_UI_Small_Click")
		local newVal = math.clamp(optionStates[settingsName] + delta, minVal, maxVal)
		optionUpdaters[settingsName](newVal)
	end

	leftBtn.MouseEnter:Connect(function() PlaySound("Roblox GUI - Hover 01") end)
	rightBtn.MouseEnter:Connect(function() PlaySound("Roblox GUI - Hover 01") end)
	leftBtn.Activated:Connect(function() changeValue(-step) end)
	rightBtn.Activated:Connect(function() changeValue(step) end)
end

----------------------------------------------------------------
-- Choice setup
----------------------------------------------------------------

local function setupChoice(option, settingsName)
	local choiceFolder = option:FindFirstChild("Choice")
	if not choiceFolder then return end

	local key = getConfigKey(settingsName)

	local choices = {}
	for _, btn in ipairs(choiceFolder:GetChildren()) do
		if btn:IsA("TextButton") then
			table.insert(choices, btn)
		end
	end

	local function getChoiceValue(btnName)
		return choiceValueMap[btnName] or btnName
	end

	local function getBtnForValue(value)
		local guiName = choiceValueMapReverse[value] or value
		for _, btn in ipairs(choices) do
			if btn.Name == guiName or btn.Text == guiName then
				return btn
			end
		end
		return nil
	end

	local function updateVisual(selectedBtn)
		for _, btn in ipairs(choices) do
			if btn == selectedBtn then
				btn.BackgroundColor3 = CHOICE_SELECTED_BG
				btn.TextColor3 = CHOICE_SELECTED_TEXT
			else
				btn.BackgroundColor3 = CHOICE_UNSELECTED_BG
				btn.TextColor3 = CHOICE_UNSELECTED_TEXT
			end
		end
	end

	local initialValue = userSettings[key] or defaultSettings[key]
	optionStates[settingsName] = initialValue
	local currentBtn = getBtnForValue(initialValue)
	updateVisual(currentBtn)

	optionUpdaters[settingsName] = function(value)
		optionStates[settingsName] = value
		local btn = getBtnForValue(value)
		if btn then
			currentBtn = btn
			updateVisual(btn)
		end
		applySetting(settingsName, value)
	end

	for _, btn in ipairs(choices) do
		btn.MouseEnter:Connect(function()
			if btn ~= currentBtn then
				PlaySound("Roblox GUI - Hover 01")
			end
		end)
		btn.Activated:Connect(function()
			if btn == currentBtn then return end
			PlaySound("Roblox_UI_Small_Click")
			currentBtn = btn
			updateVisual(btn)
			local value = getChoiceValue(btn.Name)
			optionStates[settingsName] = value
			applySetting(settingsName, value)
		end)
	end
end

----------------------------------------------------------------
-- Dropdown setup (Language)
----------------------------------------------------------------

local LANGUAGES = { "English", "Spanish", "French", "German", "Portuguese", "Japanese" }

local function setupDropdown(option, settingsName)
	local dropdown = option:FindFirstChild("Dropdown")
	if not dropdown then return end

	local label = dropdown:FindFirstChildWhichIsA("TextLabel")
	local key = getConfigKey(settingsName)
	local isPlaceholder = placeholderSettings[settingsName] ~= nil

	-- Determine initial value
	local initialValue
	if not isPlaceholder and userSettings[key] ~= nil then
		initialValue = userSettings[key]
	elseif isPlaceholder then
		initialValue = "English"
	else
		initialValue = defaultSettings[key] or "English"
	end

	-- Find the index for the initial value, default to 1
	local currentIndex = 1
	for i, lang in ipairs(LANGUAGES) do
		if lang == initialValue then
			currentIndex = i
			break
		end
	end

	optionStates[settingsName] = LANGUAGES[currentIndex]
	if label then
		label.Text = LANGUAGES[currentIndex]
	end

	optionUpdaters[settingsName] = function(value)
		local idx = 1
		for i, lang in ipairs(LANGUAGES) do
			if lang == value then
				idx = i
				break
			end
		end
		currentIndex = idx
		optionStates[settingsName] = LANGUAGES[idx]
		if label then
			label.Text = LANGUAGES[idx]
		end
		if not isPlaceholder then
			applySetting(settingsName, LANGUAGES[idx])
		end
	end

	local function cycle()
		PlaySound("Roblox_UI_Small_Click")
		currentIndex = currentIndex % #LANGUAGES + 1
		optionStates[settingsName] = LANGUAGES[currentIndex]
		if label then
			label.Text = LANGUAGES[currentIndex]
		end
		if not isPlaceholder then
			applySetting(settingsName, LANGUAGES[currentIndex])
		end
	end

	dropdown.MouseEnter:Connect(function() PlaySound("Roblox GUI - Hover 01") end)
	dropdown.Activated:Connect(cycle)
end

----------------------------------------------------------------
-- Tab switching
----------------------------------------------------------------

local function setupTabs()
	local tabButtons = {}
	for _, tabFrame in ipairs(optionList:GetChildren()) do
		if tabFrame:IsA("Frame") then
			local btn = tabFrame:FindFirstChild(tabFrame.Name)
			if btn and btn:IsA("TextButton") then
				tabButtons[tabFrame.Name] = btn
			end
		end
	end

	local function switchTab(tabName)
		PlaySound("Roblox_UI_Small_Click")
		activeTab = tabName
		for _, tabFrame in ipairs(sectionHandler:GetChildren()) do
			if tabFrame:IsA("ScrollingFrame") then
				tabFrame.Visible = (tabFrame.Name == tabName)
			end
		end
		for name, btn in pairs(tabButtons) do
			local isSelected = name == tabName
			local parentFrame = btn.Parent
			local icon = btn:FindFirstChild("Icon")

			-- TextButton background stays the same; only toggle its transparency
			btn.BackgroundTransparency = isSelected and 0 or 1

			-- Parent Frame (the "design") turns orange when selected, transparent otherwise
			if parentFrame and parentFrame:IsA("Frame") then
				parentFrame.BackgroundColor3 = TAB_ACCENT_COLOR
				parentFrame.BackgroundTransparency = isSelected and 0 or 1
			end

			-- Text color: orange when selected, white when deselected
			btn.TextColor3 = isSelected and TAB_ACCENT_COLOR or TAB_DEFAULT_COLOR

			-- Icon color: orange when selected, white when deselected
			if icon then
				icon.ImageColor3 = isSelected and TAB_ACCENT_COLOR or TAB_DEFAULT_COLOR
			end
		end
	end

	for name, btn in pairs(tabButtons) do
		btn.MouseEnter:Connect(function()
			if name ~= activeTab then
				PlaySound("Roblox GUI - Hover 01")
			end
		end)
		btn.Activated:Connect(function()
			if name ~= activeTab then
				switchTab(name)
			end
		end)
	end

	switchTab(activeTab)
end

----------------------------------------------------------------
-- Setup all options by iterating the SectionHandler tree
----------------------------------------------------------------

local function setupAllOptions()
	for _, tabFrame in ipairs(sectionHandler:GetChildren()) do
		if tabFrame:IsA("ScrollingFrame") then
			local sections = tabFrame:FindFirstChild("Sections")
			if sections then
				for _, section in ipairs(sections:GetChildren()) do
					local options = section:FindFirstChild("Options")
					if options then
						for _, option in ipairs(options:GetChildren()) do
							if option:IsA("Frame") then
								local snLabel = option:FindFirstChild("SettingsName")
								if snLabel then
									local sn = snLabel.Text
									if option:FindFirstChild("Toggle") then
										setupToggle(option, sn)
									elseif option:FindFirstChild("LeftButton") and option:FindFirstChild("RightButton") then
										setupSlider(option, sn)
									elseif option:FindFirstChild("Choice") then
										setupChoice(option, sn)
									elseif option:FindFirstChild("Dropdown") then
										setupDropdown(option, sn)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Reset to defaults
----------------------------------------------------------------

local function resetToDefaults()
	for settingsName, updater in pairs(optionUpdaters) do
		local key = getConfigKey(settingsName)
		local defaultVal = defaultSettings[key]
		if defaultVal ~= nil then
			updater(defaultVal)
		elseif placeholderSettings[settingsName] then
			updater(false)
		end
	end
end

----------------------------------------------------------------
-- Save settings
----------------------------------------------------------------

local function saveSettings()
	PlaySound("Roblox GUI - Call Accept")
	pcall(function()
		exportRemote:InvokeServer(userSettings)
	end)
end

----------------------------------------------------------------
-- Reset confirmation
----------------------------------------------------------------

local function showResetConfirmation()
	PlaySound("Swoosh Pack 1 (SFX)", true)
	AnimationController.AnimateMenu("In", "Reset")
end

local function hideResetConfirmation()
	PlaySound("Swoosh Pack 1 (SFX)", true)
	AnimationController.AnimateMenu("Out", "Reset")
end

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

loadSettings()
setupAllOptions()
setupTabs()

-- Bottom bar buttons
resetDefaultsBtn.MouseEnter:Connect(function() PlaySound("Roblox GUI - Hover 01") end)
resetDefaultsBtn.Activated:Connect(function()
	PlaySound("Roblox_UI_Small_Click")
	showResetConfirmation()
end)

saveSettingsBtn.MouseEnter:Connect(function() PlaySound("Roblox GUI - Hover 01") end)
saveSettingsBtn.Activated:Connect(function()
	saveSettings()
end)

-- Reset frame buttons
yesBtn.MouseEnter:Connect(function() PlaySound("Roblox GUI - Hover 01") end)
yesBtn.Activated:Connect(function()
	PlaySound("Roblox GUI - Negative")
	hideResetConfirmation()
	resetToDefaults()
end)






noBtn.MouseEnter:Connect(function() PlaySound("Roblox GUI - Hover 01") end)
noBtn.Activated:Connect(function()
	PlaySound("Roblox GUI - Call Accept")
	hideResetConfirmation()
end)

resetCloseBtn.MouseEnter:Connect(function() PlaySound("Roblox GUI - Hover 01") end)
resetCloseBtn.Activated:Connect(function()
	PlaySound("Roblox_UI_Small_Click")
	hideResetConfirmation()
end)

-- Save settings when player leaves
playersService.PlayerRemoving:Connect(function(player)
	if player == localPlayer then
		pcall(function()
			exportRemote:InvokeServer(userSettings)
		end)
	end
end)

script:SetAttribute("Loaded", true)


 