-- services
local userInputService = game:GetService("UserInputService")
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- remotes
local remotesFolder = replicatedStorage:WaitForChild("Remotes")
local remotes_cache = {}
for _, child in pairs(remotesFolder:GetChildren()) do
	remotes_cache[child.Name] = child
end

-- modules
local modulesFolder = replicatedStorage:WaitForChild("Modules")
local SettingsManager = require(modulesFolder:WaitForChild("SettingsManager"))
local SettingsController = require(modulesFolder:WaitForChild("SettingsManager"):WaitForChild("SettingsController"))
local SettingsConfig = require(modulesFolder:WaitForChild("SettingsManager"):WaitForChild("SettingsConfig"))
local SettingsProfile = require(script:WaitForChild("SettingsProfile"))
local AnimationController = require(script.Parent.Parent:WaitForChild("AnimationController"))
local PlaySound = require(modulesFolder:WaitForChild("PlaySound"))

-- module values
local default_settings = SettingsConfig.default_settings
local user_settings = SettingsProfile.user_settings
local button_config = SettingsConfig.button_config
local option_config = SettingsConfig.option_config

-- player
local localPlayer = playersService.LocalPlayer

-- guis
local settingsGui = localPlayer.PlayerGui:WaitForChild("SettingsGUI")
local mainFrame, resetFrame = settingsGui:WaitForChild("Main"), settingsGui:WaitForChild("Reset")
local optionsList, tabsList = mainFrame:WaitForChild("OptionsList"), mainFrame:WaitForChild("TabsList")
local topBarFrame, bottomBarFrame = mainFrame:WaitForChild("TopBar"), mainFrame:WaitForChild("BottomBar")
local actionButtonsFrame = bottomBarFrame:WaitForChild("ActionButtons")
local restoreDefaultButton = actionButtonsFrame:WaitForChild("RestoreDefault")
local noButton, yesButton = resetFrame:WaitForChild("No"), resetFrame:WaitForChild("Yes")

-- variables
local choiceDebounce = false
local dragging = false
local activeSlider = nil

-- check if previous data is there
local success, data, err = remotes_cache["GetSettingsData"]:InvokeServer()
if success and data then
	user_settings = data
else
	user_settings = default_settings
end

-- return functions
function RoundNumber(number, place)
	return math.round(number*place)/place
end

function GetRelativeX(mouseX, sliderOptionButton)
	local absPos = sliderOptionButton.AbsolutePosition.X
	local absSize = sliderOptionButton.AbsoluteSize.X
	local relX = math.clamp((mouseX - absPos) / absSize, 0, 1)
	return relX
end

function MoveSlider()
	local mousePos = userInputService:GetMouseLocation()
	local value = GetRelativeX(mousePos.X, activeSlider.sliderOptionButton)	
	SettingsController.UpdateSliderOptionValue(user_settings, activeSlider, value)
end

-- functions
function ToggleOptionSlider(value, params)
	if value then	
		activeSlider = params
	else	
		activeSlider = nil
	end
	dragging = value
end

function ShowResetMenu(stay)
	PlaySound("Swoosh Pack 1 (SFX)", true)
	AnimationController.AnimateMenu("Out", "Reset")
	if stay then
		AnimationController.AnimateMenu("In", "Settings")
	end
end

function RestoreDefaultSettings()
	for _, option in pairs(optionsList:GetChildren()) do
		if option:IsA("Frame") then	
			-- variables
			local optionData = SettingsManager.ReturnOptionData(option.Name)	
			local componentData = optionData.component
			local componentClass = option:GetAttribute("ComponentClass")

			-- get component class
			if componentClass == "boolean" then	
				SettingsController.ToggleBooleanOptionValue(user_settings, option, default_settings[option.Name])
			elseif componentClass == "range" then
				local numberOptionFrame, sliderOptionButton = option:WaitForChild("NumberOption"), option:WaitForChild("SliderOption")
				local params = {sliderOptionButton=sliderOptionButton, numberOptionFrame=numberOptionFrame, componentData=componentData}
				local min, max = params.componentData.min, params.componentData.max
				local value = default_settings[option.Name]
				local percentage = (value-min)/(max-min)
				SettingsController.UpdateSliderOptionValue(user_settings, params, percentage)
			elseif componentClass == "choice" then	
				local choicesOptionFrame = option:WaitForChild("ChoicesOption")
				local selectedChoice = choicesOptionFrame:WaitForChild(default_settings[option.Name])
				SettingsController.SelectOptionChoice(user_settings, choicesOptionFrame, option, selectedChoice)
			end
		end
	end
end

function CheckOptionComponentClass(option)
	-- variables
	local optionData = SettingsManager.ReturnOptionData(option.Name)	
	local componentData = optionData.component
	local componentClass = option:GetAttribute("ComponentClass")

	-- option component is a boolean
	if componentClass == "boolean" then	
		local booleanOption = option:WaitForChild("BooleanOption")
		local toggleButton = booleanOption:WaitForChild("Toggle")	

		-- initialize option data
		SettingsController.ToggleBooleanOptionValue(user_settings, option, user_settings[option.Name])

		-- connects
		toggleButton.MouseEnter:Connect(function()
			PlaySound("Roblox GUI - Hover 01")
		end)
		toggleButton.MouseButton1Click:Connect(function()
			PlaySound("Roblox_UI_Small_Click")
			local value
			if user_settings[option.Name] then 
				value = false 
			else 
				value = true 
			end	
			SettingsController.ToggleBooleanOptionValue(user_settings, option, value)
		end)
		booleanOption.MouseEnter:Connect(function()
			PlaySound("Roblox GUI - Hover 01")
		end)
		booleanOption.MouseButton1Click:Connect(function()
			PlaySound("Roblox_UI_Small_Click")
			local value
			if user_settings[option.Name] then 
				value = false 
			else 
				value = true 
			end	
			SettingsController.ToggleBooleanOptionValue(user_settings, option, value)
		end)
	end

	-- option component is a range
	if componentClass == "range" then	
		local numberOptionFrame, sliderOptionButton = option:WaitForChild("NumberOption"), option:WaitForChild("SliderOption")
		local sliderButton, progressSliderFrame = sliderOptionButton:WaitForChild("SliderButton"), sliderOptionButton:WaitForChild("ProgressSlider")

		-- initialize option data
		local params = {sliderOptionButton=sliderOptionButton, numberOptionFrame=numberOptionFrame, componentData=componentData}
		local min, max = params.componentData.min, params.componentData.max
		local value = user_settings[option.Name]
		local percentage = (value-min)/(max-min)
		SettingsController.UpdateSliderOptionValue(user_settings, params, percentage)

		-- connects
		sliderButton.MouseEnter:Connect(function()
			PlaySound("Roblox GUI - Hover 01")
		end)
		sliderButton.MouseButton1Down:Connect(function()	
			if dragging then return end
			PlaySound("Roblox_UI_Small_Click")
			ToggleOptionSlider(true, params)
		end)
		sliderOptionButton.MouseButton1Down:Connect(function()
			if dragging then return end
			PlaySound("Roblox_UI_Small_Click")
			ToggleOptionSlider(true, params)
			MoveSlider()
		end)
		progressSliderFrame.MouseButton1Down:Connect(function()
			if dragging then return end
			PlaySound("Roblox_UI_Small_Click")
			ToggleOptionSlider(true, params)
			MoveSlider()
		end)
	end

	-- option component is a choice
	if componentClass == "choice" then	
		local choicesOptionFrame = option:WaitForChild("ChoicesOption")

		-- intialize option choice
		local selectedChoice = choicesOptionFrame:WaitForChild(user_settings[option.Name])
		SettingsController.SelectOptionChoice(user_settings, choicesOptionFrame, option, selectedChoice)

		-- choice buttons
		for _, button in pairs(choicesOptionFrame:GetChildren()) do
			if button:IsA("TextButton") then
				-- variables
				local textlabel = button.TextLabel

				-- connects
				button.MouseLeave:Connect(function()
					if user_settings[option.Name] == button.Name then return end

					-- reset tab properties to unselected (player is nolonger hovering over the tab)
					button.BackgroundTransparency 		= button_config.unselected.background_transparency
					textlabel.TextColor3 				= button_config.unselected.color
					textlabel.TextTransparency 			= button_config.unselected.transparency
					textlabel.FontFace					= button_config.unselected.fontface
				end)
				button.MouseEnter:Connect(function()
					if user_settings[option.Name] == button.Name then return end

					-- set tab properties to hovered (player is currently hovering over the tab)
					PlaySound("Roblox GUI - Hover 01")
					button.BackgroundTransparency 		= button_config.hovered.background_transparency
					textlabel.TextColor3 				= button_config.hovered.color
					textlabel.TextTransparency 			= button_config.hovered.transparency
					textlabel.FontFace					= button_config.hovered.fontface
				end)
				button.MouseButton1Click:Connect(function()
					if user_settings[option.Name] == button.Name then return end
					if choiceDebounce then return end

					-- player clicked on a tab (the tab is not already open)
					PlaySound("Roblox_UI_Small_Click")
					choiceDebounce = true
					SettingsController.SelectOptionChoice(user_settings, choicesOptionFrame, option, button)
					choiceDebounce = false
				end)			
			end
		end		
	end
end

-- load options into memory
for _, option in pairs(optionsList:GetChildren()) do
	if option:IsA("Frame") then
		-- check component
		CheckOptionComponentClass(option)
		
		-- connects
		option.MouseEnter:Connect(function()
			option.BackgroundColor3 					= option_config.hovered.color
			option.BackgroundTransparency 				= option_config.hovered.transparency
		end)
		option.MouseLeave:Connect(function()
			option.BackgroundColor3 					= option_config.unhovered.color
			option.BackgroundTransparency 				= option_config.unhovered.transparency
		end)
	end
end
script:SetAttribute("Loaded", true)

-- players removing
playersService.PlayerRemoving:Connect(function(player)
	remotes_cache["ExportSettingsFunction"]:InvokeServer(user_settings)
end)

-- user input
userInputService.InputEnded:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
		PlaySound("Roblox_UI_Small_Click")
		ToggleOptionSlider(false)
	end
end)
userInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then	return end
	MoveSlider()
end)

-- restore default buttons
restoreDefaultButton.MouseEnter:Connect(function()
	PlaySound("Roblox GUI - Hover 01")
end)
restoreDefaultButton.MouseButton1Click:Connect(function()
	PlaySound("Roblox GUI - Swipe")
	PlaySound("Swoosh Pack 1 (SFX)", true)
	AnimationController.AnimateMenu("Out", "Settings")
	AnimationController.AnimateMenu("In", "Reset")
end)
noButton.MouseEnter:Connect(function()
	PlaySound("Roblox GUI - Hover 01")
end)
noButton.MouseButton1Click:Connect(function()
	PlaySound("Roblox GUI - Call Accept")
	ShowResetMenu(true)
end)
yesButton.MouseEnter:Connect(function()
	PlaySound("Roblox GUI - Hover 01")
end)
yesButton.MouseButton1Click:Connect(function()
	PlaySound("Roblox GUI - Negative")
	ShowResetMenu()
	RestoreDefaultSettings()
	--print("Restored Settings to Default For: "..localPlayer.Name)
end)
