-- services

print("Main Developer: Sacredbow1")
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- player
local localPlayer = playersService.LocalPlayer

-- modules
local modulesFolder = replicatedStorage:WaitForChild("Modules")
local AnimationController = require(script.Parent:WaitForChild("AnimationController"))
local PlaySound = require(modulesFolder:WaitForChild("PlaySound"))

-- guis
local newSettingsGui = localPlayer.PlayerGui:WaitForChild("NewSettings")
local topbarGui = localPlayer.PlayerGui:WaitForChild("TopbarGUI")
local settingsBackground = newSettingsGui:WaitForChild("SettingsBackground")
local topbarButtons = topbarGui:WaitForChild("Buttons")
local settingsButton = topbarButtons:WaitForChild("Settings")

-- close button inside NewSettings
local topBar = settingsBackground:WaitForChild("TopBar")
local closeButton = topBar:WaitForChild("Close")

-- values
local debounce = false

-- settings button
settingsButton.MouseEnter:Connect(function()
	if debounce then return end
	PlaySound("Roblox GUI - Hover 01")
end)
settingsButton.MouseButton1Click:Connect(function()
	if debounce then return end
	debounce = true
	PlaySound("Roblox_UI_Small_Click")
	PlaySound("Swoosh Pack 1 (SFX)", true)
	if settingsBackground.Visible then
		AnimationController.AnimateMenu("Out", "Settings")
	else
		AnimationController.AnimateMenu("In", "Settings")
	end
	debounce = false
end)

-- close button inside NewSettings
closeButton.MouseEnter:Connect(function()
	PlaySound("Roblox GUI - Hover 01")
end)
closeButton.MouseButton1Click:Connect(function()
	if debounce then return end
	debounce = true
	PlaySound("Roblox_UI_Small_Click")
	PlaySound("Swoosh Pack 1 (SFX)", true)
	AnimationController.AnimateMenu("Out", "Settings")
	debounce = false
end)