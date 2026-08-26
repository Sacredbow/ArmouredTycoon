-- services
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
-- folders
local modulesFolder =replicatedStorage:WaitForChild("Modules")

-- modules
local SettingsManager = require(modulesFolder:WaitForChild("SettingsManager"))
local SettingsConfig = require(modulesFolder:WaitForChild("SettingsManager"):WaitForChild("SettingsConfig"))
local PlaySound = require(modulesFolder:WaitForChild("PlaySound"))

-- module values
local button_config = SettingsConfig.button_config

-- player
local localPlayer = playersService.LocalPlayer

-- guis
local settingsGui = localPlayer.PlayerGui:WaitForChild("SettingsGUI")
local mainFrame = settingsGui:WaitForChild("Main")
local optionsList, tabsList = mainFrame:WaitForChild("OptionsList"), mainFrame:WaitForChild("TabsList")
local topBarFrame, bottomBarFrame = mainFrame:WaitForChild("TopBar"), mainFrame:WaitForChild("BottomBar")

-- variables
local activeTab = ""
local debounce = false

-- load
SettingsManager.InitializeSettings()

-- functions
function UnselectAllTabs()
	activeTab = ""
	for _, button in pairs(tabsList:GetChildren()) do	
		if button:IsA("TextButton") then	
			-- variables
			local textlabel = button.TextLabel
			
			-- properties
			button.BackgroundTransparency 		= button_config.unselected.background_transparency
			button.IconImage.ImageColor3 		= button_config.unselected.color
			textlabel.TextColor3 				= button_config.unselected.color
			textlabel.TextTransparency 			= button_config.unselected.transparency
			button.IconImage.ImageTransparency 	= button_config.unselected.transparency
			textlabel.FontFace					= button_config.unselected.fontface
		end	
	end
end

function SelectTab(button)
	UnselectAllTabs()
	
	-- variables
	local textlabel = button.TextLabel
	
	-- properties
	button.BackgroundTransparency 		= button_config.active.background_transparency
	button.IconImage.ImageColor3 		= button_config.active.color
	textlabel.TextColor3 				= button_config.active.color
	textlabel.TextTransparency 			= button_config.active.transparency
	button.IconImage.ImageTransparency 	= button_config.active.transparency
	textlabel.FontFace					= button_config.active.fontface
	
	-- enable options for that tab
	for _, frame in pairs(optionsList:GetChildren()) do	
		if frame:IsA("Frame") then	
			local tabIdAttribute = frame:GetAttribute("TabId")
			if tabIdAttribute == button.Name then
				frame.Visible = true
			else
				frame.Visible = false
			end		
		end	
	end
	activeTab = button.Name
end

-- tabs controller
for _, button in pairs(tabsList:GetChildren()) do
	if button:IsA("TextButton") then	
		-- variables
		local textlabel = button.TextLabel
		
		-- connects
		button.MouseLeave:Connect(function()
			if activeTab == button.Name then return end
			
			-- reset tab properties to unselected (player is nolonger hovering over the tab)
			button.BackgroundTransparency 		= button_config.unselected.background_transparency
			button.IconImage.ImageColor3 		= button_config.unselected.color
			textlabel.TextColor3 				= button_config.unselected.color
			textlabel.TextTransparency 			= button_config.unselected.transparency
			button.IconImage.ImageTransparency 	= button_config.unselected.transparency
			textlabel.FontFace					= button_config.unselected.fontface
		end)	
		button.MouseEnter:Connect(function()
			if activeTab == button.Name then return end
			
			-- set tab properties to hovered (player is currently hovering over the tab)
			PlaySound("Roblox GUI - Hover 01")
			button.BackgroundTransparency 		= button_config.hovered.background_transparency
			button.IconImage.ImageColor3 		= button_config.hovered.color
			textlabel.TextColor3 				= button_config.hovered.color
			textlabel.TextTransparency 			= button_config.hovered.transparency
			button.IconImage.ImageTransparency 	= button_config.hovered.transparency	
			textlabel.FontFace					= button_config.hovered.fontface
		end)	
		button.MouseButton1Click:Connect(function()
			if activeTab == button.Name then return end
			if debounce then return end
			
			-- player clicked on a tab (the tab is not already open)
			PlaySound("Roblox_UI_Small_Click")
			debounce = true
			SelectTab(button)
			debounce = false
		end)	
	end
end
script.OptionsHandler.Enabled = true
local loaded
repeat 
	loaded = script.OptionsHandler:GetAttribute("Loaded")
	wait()
until loaded == true
local defaultTab = tabsList:FindFirstChild(SettingsConfig.default_settings_tab)
if defaultTab then
	SelectTab(defaultTab)
end
