-- services
local tweenSerivce = game:GetService("TweenService")
local soundService = game:GetService("SoundService")
local players = game:GetService("Players")
-- sounds
local function getOrCreateSoundGroup(name)
	local soundGroup = soundService:FindFirstChild(name)
	if soundGroup and soundGroup:IsA("SoundGroup") then
		return soundGroup
	end

	soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = name
	soundGroup.Parent = soundService
	return soundGroup
end

local musicGroup, sfxGroup = getOrCreateSoundGroup("Music"), getOrCreateSoundGroup("SFX")
local localPlayer = players.LocalPlayer

-- main
local SettingsUpdater = {}

function SettingsUpdater.ApplySetting(user_settings, name, value)
	-- audio
	if name == "Music Volume" then
		if user_settings["Mute Music"] == false then
			musicGroup.Volume = value
		else
			musicGroup.Volume = 0
		end
	elseif name == "Mute Music" then
		if value then
			musicGroup.Volume = 0
		else
			musicGroup.Volume = user_settings["Music Volume"] 
		end
	elseif name == "SFX Volume" then
		if user_settings["Mute SFX"] == false then
			sfxGroup.Volume = value
		else
			sfxGroup.Volume = 0
		end
	elseif name == "Mute SFX" then
		if value then
			sfxGroup.Volume = 0
		else
			sfxGroup.Volume = user_settings["SFX Volume"] 
		end
	end
	
	-- graphics
	if name == "Shadows" then
		game.Lighting.GlobalShadows = value
	elseif name == "Shadow Quality" then
		if value == "Lowest" then
			game.Lighting.ShadowSoftness = 0
		elseif value == "Normal" then
			game.Lighting.ShadowSoftness = 0.25
		elseif value == "Highest" then
			game.Lighting.ShadowSoftness = 0.5
		end
	elseif name == "Bloom" then
		game.Lighting.Bloom.Enabled = value
	elseif name == "Sun Rays" then
		game.Lighting.SunRays.Enabled = value
	end
	
	-- gameplay
	if name == "Third Person" and localPlayer then
		localPlayer:SetAttribute("ThirdPersonCameraEnabled", value == true)
		localPlayer:SetAttribute("CameraModePreference", if value == true then "Third Person" else "First Person")
	elseif name == "Field of View" then
		if localPlayer then
			localPlayer:SetAttribute("CameraBaseFOV", value)
		end
		tweenSerivce:Create(workspace.Camera, TweenInfo.new(0.5), {FieldOfView = value}):Play()
	elseif name == "User Announcements" and localPlayer then
		localPlayer:SetAttribute("SuppressUserAnnouncements", value ~= true)
	elseif name == "Allow Button Directions" and localPlayer then
		localPlayer:SetAttribute("AllowButtonDirections", value == true)
	end
end

return SettingsUpdater
