--!strict


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ServerStorage = game:GetService("ServerStorage")

local Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
local Evt 	= Engine:WaitForChild("Events")
local SFX = SoundService.SFX
local RefillSound = SFX.Common.Interactions.RefillSound


local Universal 	= true
local BulletType 	= "Universal"
local Infinite 		= true
local Stored 		=  ServerStorage.Constants.Stored

local ReloadConfig = {}

type GunSettingsType = {
	Type: string,
	BulletType : string
}


--if not Infinite then
--	script.Parent.ObjectText = BulletType.." | "..Stored.Value
--else
--	script.Parent.ObjectText = BulletType
--end

function ReloadConfig.onPromptTriggered(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local settingsModule = child:FindFirstChild("ACS_Settings")
			local clientState = child:FindFirstChild("ACS_Client")
			local storedValue = clientState and clientState:FindFirstChild("Stored")
			local totalMagsValue = clientState and clientState:FindFirstChild("TotalMags")

			if settingsModule and storedValue and totalMagsValue and storedValue:IsA("NumberValue") and totalMagsValue:IsA("NumberValue") then
				local gunSettings = require(settingsModule) :: GunSettingsType
				local compatibleAmmo = Universal or gunSettings.BulletType == BulletType

				if gunSettings.Type == "Gun" and compatibleAmmo then
					storedValue.Value = totalMagsValue.Value
					Evt.Refil:FireClient(player, child, Infinite, Stored)
					RefillSound:Play()
				end
			end
		end
	end
end

Stored.Changed:Connect(function()
	if not Infinite then
		script.Parent.ObjectText = BulletType.." | "..Stored.Value
	else
		script.Parent.ObjectText = BulletType
	end
end)


return ReloadConfig
