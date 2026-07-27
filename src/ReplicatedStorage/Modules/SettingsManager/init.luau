-- services
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
-- folders
local guisFolder = replicatedStorage:FindFirstChild("GUIs")
-- player
local localPlayer = players.LocalPlayer
-- modules
local SettingsConfig = require(script:WaitForChild("SettingsConfig"))
-- module values
-- local default_settings = SettingsConfig.default_settings
-- local component_config = SettingsConfig.component_config

local SettingsManager = {}

function GetOptionType(component, option)
	if not guisFolder then
		return
	end

	local componentFrames = SettingsManager.ReturnComponent(component.class, option)
	if componentFrames[1].Name == "ChoicesOption" then
		local length = 0.9
		local entries = #component.choices
		local xsize = length/entries
		for index, value in pairs(component.choices) do		
			local choiceClone = guisFolder.choiceExample:Clone()
			choiceClone.Parent = componentFrames[1]
			choiceClone.Name = value
			choiceClone.Size = UDim2.new(xsize, 0, 1, 0)
			choiceClone.TextLabel.Text = value	
			choiceClone.Visible = true
		end
	end
end

function SettingsManager.ReturnComponent(class, option)
	local frames = {}
	if class == "boolean" then	
		table.insert(frames, "BooleanOption")	
	elseif class == "range" then	
		table.insert(frames, "SliderOption")
		table.insert(frames, "NumberOption")
	elseif class == "choice" then		
		table.insert(frames, "ChoicesOption")		
	end
	local result = {}
	for index, id in pairs(frames) do	
		local componentFrame = option:WaitForChild(id)
		componentFrame.Visible = true
		table.insert(result, componentFrame)
	end
	return result
end

function SettingsManager.ReturnOptionData(name)
	for id, array in pairs(SettingsConfig.settings_options) do	
		for index, data in pairs(array) do			
			if data.name == name then
				return data
			end		
		end	
		
	end
	return nil
end

function SettingsManager.InitializeSettings()
	-- resolve GUI references here, not at module load time
	if not guisFolder then
		warn("[SettingsManager] Legacy ReplicatedStorage.GUIs folder was not found; skipping legacy settings UI initialization.")
		return false
	end

	local settingsGui = localPlayer.PlayerGui:FindFirstChild("SettingsGUI") or localPlayer.PlayerGui:WaitForChild("SettingsGUI", 5)
	if not settingsGui then
		warn("[SettingsManager] Legacy SettingsGUI was not found; skipping legacy settings UI initialization.")
		return false
	end

	local mainFrame = settingsGui:WaitForChild("Main")
	local optionsList = mainFrame:WaitForChild("OptionsList")
	local tabsList = mainFrame:WaitForChild("TabsList")

	for _, data in pairs(SettingsConfig.settings_tabs) do		
		local tabClone = guisFolder.tabExample:Clone()
		tabClone.Parent = tabsList
		tabClone.Name = data.name
		tabClone.IconImage.Image = data.image_id
		tabClone.TextLabel.Text = data.name
	end

	for id, array in pairs(SettingsConfig.settings_options) do		
		for index, data in pairs(array) do		
			local optionClone = guisFolder.optionExample:Clone()
			optionClone.Parent = optionsList
			optionClone.Name = data.name
			optionClone.TextLabel.Text = data.name	
			optionClone:SetAttribute("TabId", id)
			optionClone:SetAttribute("ComponentClass", data.component.class)
			GetOptionType(data.component, optionClone)			
		end		
	end

	return true
end

return SettingsManager
