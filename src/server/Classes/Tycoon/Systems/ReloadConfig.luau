--!strict


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ServerStorage = game:GetService("ServerStorage")

local Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
local Evt 	= Engine:WaitForChild("Events")
local SFX = SoundService.SFX
local RefillSound = SFX.RefillSound


local Universal 	= false
local BulletType 	= "Universal"
local Infinite 		= true
local Stored 		=  ServerStorage.Constants.Stored

local ReloadConfig = {}

type GunSettingsType = {
	Type: string,
	BulletType : string
}


if not Infinite then
	script.Parent.ObjectText = BulletType.." | "..Stored.Value
else
	script.Parent.ObjectText = BulletType
end

function ReloadConfig.onPromptTriggered(player)
	if player.Character and player.Character:FindFirstChild("Humanoid") ~= nil and player.Character.Humanoid.Health > 0 then

		for _,Child in pairs(player.Character:GetChildren()) do
			
			
	if Child:IsA("Tool") then
	local ACS_Settings = Child.ACS_Settings
	local GunSettings = require(ACS_Settings) :: GunSettingsType
	if GunSettings.Type == "Gun" and Stored.Value > 0 then
     	if Universal then
						
		Evt.Refil:FireClient(player, Child, Infinite, Stored)
		RefillSound:Play()
						
	else
		if GunSettings.BulletType == BulletType then
				Evt.Refil:FireClient(player, Child, Infinite, Stored)
	RefillSound:Play()
						end
				  end
			
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