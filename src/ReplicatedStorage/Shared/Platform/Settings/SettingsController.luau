-- services
local tweenService = game:GetService("TweenService")

-- modules
local SettingsManager = require(script.Parent)
local SettingsUpdater = require(script.Parent:WaitForChild("SettingsUpdater"))
local SettingsConfig = require(script.Parent:WaitForChild("SettingsConfig"))

-- module values
local button_config = SettingsConfig.button_config
local component_config = SettingsConfig.component_config

-- main
local SettingsController = {}

-- functions
function ResetOptionChoices(list)
	for _, button in list:GetChildren() do
		if button:IsA("TextButton") then
			-- variables
			local textlabel = button.TextLabel

			-- properties
			button.BackgroundTransparency = button_config.unselected.background_transparency
			textlabel.TextColor3 = button_config.unselected.color
			textlabel.TextTransparency = button_config.unselected.transparency
			textlabel.FontFace = button_config.unselected.fontface
		end
	end
end

function UpdateOptionComponent(option, value)
	local componentClass = option:GetAttribute("ComponentClass")
	local componentFrames = SettingsManager.ReturnComponent(componentClass, option)

	-- get option component
	if componentFrames[1].Name == "BooleanOption" then
		local toggleButton = componentFrames[1].Toggle
		if value then
			toggleButton.Position = component_config.boolean.enabled_position
			toggleButton.BackgroundColor3 = component_config.boolean.enabled_backgroundcolor
			toggleButton.TextLabel.TextColor3 = component_config.boolean.enabled_textcolor
			toggleButton.TextLabel.FontFace = component_config.boolean.enabled_fontface
			toggleButton.TextLabel.Text = "On"
		else
			toggleButton.Position = component_config.boolean.disabled_position
			toggleButton.BackgroundColor3 = component_config.boolean.disabled_backgroundcolor
			toggleButton.TextLabel.TextColor3 = component_config.boolean.disabled_textcolor
			toggleButton.TextLabel.FontFace = component_config.boolean.disabled_fontface
			toggleButton.TextLabel.Text = "Off"
		end
	end
end

-- module functions
function SettingsController.ToggleBooleanOptionValue(user_settings, option, value)
	UpdateOptionComponent(option, value)
	user_settings[option.Name] = value
	SettingsUpdater.ApplySetting(user_settings, option.Name, value)
end

function SettingsController.UpdateSliderOptionValue(user_settings, params, percentage)
	local optionFrame = params.sliderOptionButton.Parent
	local min, max, suffix = params.componentData.min, params.componentData.max, params.componentData.suffix

	-- formats
	local number = min + (percentage * (max - min))

	-- display value
	local text = ""
	if suffix then
		text = tostring(math.floor(percentage * 100)) .. suffix
	else
		text = tostring(math.floor(number))
	end

	-- display the option value on the textbox
	params.numberOptionFrame.TextLabel.Text = text

	-- update the progress bar and slider
	tweenService
		:Create(
			params.sliderOptionButton.ProgressSlider,
			TweenInfo.new(SettingsConfig.slider_speed),
			{ Size = UDim2.new(percentage, 0, 1, 0) }
		)
		:Play()
	tweenService
		:Create(
			params.sliderOptionButton.SliderButton,
			TweenInfo.new(SettingsConfig.slider_speed),
			{ Position = UDim2.new(percentage, 0, 0.5, 0) }
		)
		:Play()

	-- set the new value for that option
	user_settings[optionFrame.Name] = number
	SettingsUpdater.ApplySetting(user_settings, optionFrame.Name, number)
end

function SettingsController.SelectOptionChoice(user_settings, list, option, button)
	ResetOptionChoices(list)

	-- variables
	local textlabel = button.TextLabel

	-- properties
	button.BackgroundTransparency = button_config.active.background_transparency
	textlabel.TextColor3 = button_config.active.color
	textlabel.TextTransparency = button_config.active.transparency
	textlabel.FontFace = button_config.active.fontface

	-- enable option choice
	user_settings[option.Name] = button.Name
	SettingsUpdater.ApplySetting(user_settings, option.Name, button.Name)
end

return SettingsController
