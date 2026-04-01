-- services
local tweenSerivce = game:GetService("TweenService")
local soundService = game:GetService("SoundService")
-- sounds
local musicGroup, sfxGroup = soundService:WaitForChild("Music"), soundService:WaitForChild("SFX")

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
	if name == "Field of View" then
		tweenSerivce:Create(workspace.Camera, TweenInfo.new(0.5), {FieldOfView = value}):Play()
	end
end

return SettingsUpdater
