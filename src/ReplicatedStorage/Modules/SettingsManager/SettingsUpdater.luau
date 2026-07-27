--!strict

local Lighting = game:GetService('Lighting')
local SoundService = game:GetService('SoundService')
local TweenService = game:GetService('TweenService')
local Workspace = game:GetService('Workspace')

local RuntimeSettings = require(script.Parent.RuntimeSettings)

type UserSettings = { [string]: any }

local SettingsUpdater = {}

local function getOrCreateSoundGroup(name: string): SoundGroup
	local soundGroup = SoundService:FindFirstChild(name)
	if soundGroup and soundGroup:IsA('SoundGroup') then
		return soundGroup
	end

	soundGroup = Instance.new('SoundGroup')
	soundGroup.Name = name
	soundGroup.Parent = SoundService
	return soundGroup
end

local function setSoundGroupsByName(name: string, volume: number)
	local found = false
	for _, child in ipairs(SoundService:GetChildren()) do
		if child:IsA('SoundGroup') and child.Name == name then
			child.Volume = volume
			found = true
		end
	end

	if not found then
		getOrCreateSoundGroup(name).Volume = volume
	end
end

local musicGroup = getOrCreateSoundGroup('Music')
local sfxGroup = getOrCreateSoundGroup('SFX')
getOrCreateSoundGroup('NatureAudioGroup')
getOrCreateSoundGroup('WeatherAudioGroup')

function SettingsUpdater.ApplySetting(userSettings: UserSettings, name: string, value: any)
	if name == 'Music Volume' then
		musicGroup.Volume = if userSettings['Mute Music'] == false then value else 0
	elseif name == 'Mute Music' then
		musicGroup.Volume = if value then 0 else userSettings['Music Volume']
	elseif name == 'SFX Volume' then
		sfxGroup.Volume = if userSettings['Mute SFX'] == false then value else 0
	elseif name == 'Mute SFX' then
		sfxGroup.Volume = if value then 0 else userSettings['SFX Volume']
	elseif name == 'Wind' then
		RuntimeSettings.Set('Wind', value == true)
	elseif name == 'Environmental Volume' then
		local enabled = value == true
		RuntimeSettings.Set('Environmental Volume', enabled)
		setSoundGroupsByName('WeatherAudioGroup', if enabled then 1 else 0)
	end

	if name == 'Shadows' then
		Lighting.GlobalShadows = value
	elseif name == 'Shadow Quality' then
		if value == 'Lowest' then
			Lighting.ShadowSoftness = 0
		elseif value == 'Normal' then
			Lighting.ShadowSoftness = 0.25
		elseif value == 'Highest' then
			Lighting.ShadowSoftness = 0.5
		end
	elseif name == 'Bloom' then
		local bloom = Lighting:FindFirstChildOfClass('BloomEffect')
		if bloom then
			bloom.Enabled = value == true
		end
	elseif name == 'Sun Rays' then
		local sunRays = Lighting:FindFirstChildOfClass('SunRaysEffect')
		if sunRays then
			sunRays.Enabled = value == true
		end
	end

	if name == 'Third Person' then
		RuntimeSettings.Set('Third Person', value == true)
	elseif name == 'Field of View' then
		local numericValue = tonumber(value)
		if numericValue then
			RuntimeSettings.Set('Field of View', numericValue)
			local camera = Workspace.CurrentCamera
			if camera then
				TweenService:Create(camera, TweenInfo.new(0.5), { FieldOfView = numericValue }):Play()
			end
		end
	elseif name == 'User Announcements' then
		RuntimeSettings.Set('User Announcements', value == true)
	elseif name == 'Allow Button Directions' then
		RuntimeSettings.Set('Allow Button Directions', value == true)
	end
end

return SettingsUpdater
