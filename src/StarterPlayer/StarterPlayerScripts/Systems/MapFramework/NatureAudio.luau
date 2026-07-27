--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EnvironmentShared = require(ReplicatedStorage.EnvironmentShared)

local NatureAudio = {}
NatureAudio.__index = NatureAudio

local NATURE_SOUNDS = EnvironmentShared.NatureSounds
local RAIN_SOUND_ID = "rbxassetid://1516791621"
local RAIN_LOOP_LENGTH = 30
local WIND_VOLUME = {
	GeneralBase = 0.52,
	GeneralWindScale = 1.1,
	GeneralMax = 1.9,
	HeavyScale = 1.65,
	HeavyMax = 1.8,
	IndoorFloor = 0.48,
}

local ROOF_SAMPLE_OFFSETS = {
	Vector3.zero,
	Vector3.new(5, 0, 0),
	Vector3.new(-5, 0, 0),
	Vector3.new(0, 0, 5),
	Vector3.new(0, 0, -5),
	Vector3.new(3.5, 0, 3.5),
	Vector3.new(-3.5, 0, 3.5),
	Vector3.new(3.5, 0, -3.5),
	Vector3.new(-3.5, 0, -3.5),
}

local WALL_DIRECTIONS = {
	Vector3.new(1, 0.15, 0),
	Vector3.new(-1, 0.15, 0),
	Vector3.new(0, 0.15, 1),
	Vector3.new(0, 0.15, -1),
	Vector3.new(0.7, 0.15, 0.7).Unit,
	Vector3.new(-0.7, 0.15, 0.7).Unit,
	Vector3.new(0.7, 0.15, -0.7).Unit,
	Vector3.new(-0.7, 0.15, -0.7).Unit,
}

type SoundSet = {
	generalWind: Sound,
	generalWindB: Sound,
	heavyWind: Sound,
	heavyWindB: Sound,
	rain: Sound,
	rainB: Sound,
	gust: Sound,
	birds: Sound,
	equalizer: EqualizerSoundEffect,
	reverb: ReverbSoundEffect,
}

export type NatureAudio = typeof(setmetatable({} :: {
	_folder: Folder,
	_sounds: SoundSet,
	_weather: any,
	_windEnabled: boolean,
	_environmentAudioEnabled: boolean,
	_exposure: number,
	_roofCover: number,
	_wallOpen: number,
	_destroyed: boolean,
	_lastGustAt: number,
	_lastBirdAt: number,
	_targets: { [string]: number },
	_loopSwap: { [string]: boolean },
}, NatureAudio))

local function makeSound(parent: Instance, name: string, soundId: string, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = looped
	sound.Volume = 0
	sound.PlaybackSpeed = 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = parent
	return sound
end

local function attachEffects(sound: Sound, equalizer: EqualizerSoundEffect, reverb: ReverbSoundEffect)
	equalizer:Clone().Parent = sound
	reverb:Clone().Parent = sound
end

local function tween(instance: Instance, duration: number, goals: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), goals):Play()
end

local function tweenNumber(self: NatureAudio, key: string, instance: Instance, property: string, value: number, duration: number)
	local last = self._targets[key]
	if last and math.abs(last - value) < 0.025 then
		return
	end

	self._targets[key] = value
	tween(instance, duration, {
		[property] = value,
	})
end

local function getListenerPosition(): Vector3?
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end

	return nil
end

function NatureAudio.new(): NatureAudio
	local folder = Instance.new("Folder")
	folder.Name = "NatureAudio"
	folder.Parent = SoundService

	local soundGroup = SoundService:FindFirstChild("NatureAudioGroup")
	if not soundGroup or not soundGroup:IsA("SoundGroup") then
		soundGroup = Instance.new("SoundGroup")
		soundGroup.Name = "NatureAudioGroup"
		soundGroup.Parent = SoundService
	end
	soundGroup.Volume = 1.65

	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.Name = "ExposureMuffle"
	equalizer.HighGain = 0
	equalizer.MidGain = 0
	equalizer.LowGain = 0

	local reverb = Instance.new("ReverbSoundEffect")
	reverb.Name = "ExposureRoom"
	reverb.DecayTime = 0.25
	reverb.Density = 0.2
	reverb.Diffusion = 0.25
	reverb.DryLevel = 0
	reverb.WetLevel = -80

	local generalWind = makeSound(folder, "GeneralWind", NATURE_SOUNDS.GeneralWind.soundId, true)
	local generalWindB = makeSound(folder, "GeneralWindCrossfade", NATURE_SOUNDS.GeneralWind.soundId, true)
	local heavyWind = makeSound(folder, "HeavyWind", NATURE_SOUNDS.HeavyWind.soundId, true)
	local heavyWindB = makeSound(folder, "HeavyWindCrossfade", NATURE_SOUNDS.HeavyWind.soundId, true)
	local rain = makeSound(folder, "RainBed", RAIN_SOUND_ID, true)
	local rainB = makeSound(folder, "RainBedCrossfade", RAIN_SOUND_ID, true)
	local gust = makeSound(folder, "WindGust", NATURE_SOUNDS.WindGust.soundId, false)
	local birds = makeSound(folder, "BirdCoo", NATURE_SOUNDS.BirdCoo.soundId, false)
	generalWind.SoundGroup = soundGroup
	generalWindB.SoundGroup = soundGroup
	heavyWind.SoundGroup = soundGroup
	heavyWindB.SoundGroup = soundGroup
	rain.SoundGroup = soundGroup
	rainB.SoundGroup = soundGroup
	gust.SoundGroup = soundGroup
	birds.SoundGroup = soundGroup

	attachEffects(generalWind, equalizer, reverb)
	attachEffects(generalWindB, equalizer, reverb)
	attachEffects(heavyWind, equalizer, reverb)
	attachEffects(heavyWindB, equalizer, reverb)
	attachEffects(rain, equalizer, reverb)
	attachEffects(rainB, equalizer, reverb)
	attachEffects(gust, equalizer, reverb)
	equalizer.Parent = birds
	reverb.Parent = birds

	generalWind:Play()
	generalWindB.TimePosition = NATURE_SOUNDS.GeneralWind.length * 0.5
	generalWindB:Play()
	heavyWind:Play()
	heavyWindB.TimePosition = NATURE_SOUNDS.HeavyWind.length * 0.5
	heavyWindB:Play()
	rain:Play()
	rainB.TimePosition = RAIN_LOOP_LENGTH * 0.5
	rainB:Play()

	local self = setmetatable({
		_folder = folder,
		_sounds = {
			generalWind = generalWind,
			generalWindB = generalWindB,
			heavyWind = heavyWind,
			heavyWindB = heavyWindB,
			rain = rain,
			rainB = rainB,
			gust = gust,
			birds = birds,
			equalizer = equalizer,
			reverb = reverb,
		},
		_weather = nil,
		_windEnabled = true,
		_environmentAudioEnabled = true,
		_exposure = 1,
		_roofCover = 0,
		_wallOpen = 1,
		_destroyed = false,
		_lastGustAt = -math.huge,
		_lastBirdAt = -math.huge,
		_targets = {},
		_loopSwap = {},
	}, NatureAudio)

	task.spawn(function()
		self:_loop()
	end)

	return self
end

function NatureAudio:_measureExposure(): (number, number, number)
	local position = getListenerPosition()
	if not position then
		return self._exposure, self._roofCover, self._wallOpen
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	params.IgnoreWater = true

	local roofHits = 0
	for _, offset in ipairs(ROOF_SAMPLE_OFFSETS) do
		local result = Workspace:Raycast(position + offset, Vector3.new(0, 180, 0), params)
		if result then
			roofHits += 1
		end
	end

	local wallOpen = 0
	for _, direction in ipairs(WALL_DIRECTIONS) do
		local result = Workspace:Raycast(position, direction * 75, params)
		if not result then
			wallOpen += 1
		end
	end

	local roofCover = roofHits / #ROOF_SAMPLE_OFFSETS
	local wallOpenRatio = wallOpen / #WALL_DIRECTIONS
	local exposure = math.clamp((1 - roofCover) * 0.68 + wallOpenRatio * 0.32, 0, 1)
	return exposure, roofCover, wallOpenRatio
end

function NatureAudio:_applyMuffle(exposure: number)
	local indoor = math.clamp(self._roofCover * 0.78 + (1 - self._wallOpen) * 0.22, 0, 1)
	for index, sound in { self._sounds.generalWind, self._sounds.generalWindB, self._sounds.heavyWind, self._sounds.heavyWindB, self._sounds.rain, self._sounds.rainB, self._sounds.gust, self._sounds.birds } do
		local eq = sound:FindFirstChild("ExposureMuffle")
		local rv = sound:FindFirstChild("ExposureRoom")
		if eq and eq:IsA("EqualizerSoundEffect") then
			tweenNumber(self, "eqHigh" .. index, eq, "HighGain", -34 * indoor, 0.8)
			tweenNumber(self, "eqMid" .. index, eq, "MidGain", -14 * indoor, 0.8)
			tweenNumber(self, "eqLow" .. index, eq, "LowGain", -4 * indoor, 0.8)
		end
		if rv and rv:IsA("ReverbSoundEffect") then
			tweenNumber(self, "rvWet" .. index, rv, "WetLevel", -80 + indoor * 62, 0.8)
			tweenNumber(self, "rvDecay" .. index, rv, "DecayTime", 0.25 + indoor * 1.1, 0.8)
		end
	end
end

function NatureAudio:ApplyWeather(weather)
	self._weather = weather
	local exposure = self._exposure
	local windPresence = math.clamp(weather.windSpeed / 38, 0, 1) * math.clamp(weather.windPower, 0, 1)
	local exposureVolume = math.clamp(WIND_VOLUME.IndoorFloor + exposure * (1 - WIND_VOLUME.IndoorFloor), 0, 1)
	local heavyPresence = math.clamp((weather.windSpeed - 15) / 24, 0, 1) * math.clamp(weather.windPower, 0, 1)
	local rainExposure = self:GetRainExposure()
	local windAudioScale = if self._windEnabled then 1 else 0
	local environmentAudioScale = if self._environmentAudioEnabled then 1 else 0
	local generalVolume = math.clamp(
		WIND_VOLUME.GeneralBase + windPresence * WIND_VOLUME.GeneralWindScale,
		0,
		WIND_VOLUME.GeneralMax
	) * exposureVolume * windAudioScale
	local heavyVolume = math.clamp(heavyPresence * WIND_VOLUME.HeavyScale, 0, WIND_VOLUME.HeavyMax) * exposureVolume * windAudioScale
	local rainVolume = math.clamp(weather.rainIntensity * (0.7 + weather.windPower * 0.24), 0, 1.25)
		* math.clamp(0.18 + rainExposure * 0.82, 0, 1)
		* environmentAudioScale

	if not self._sounds.generalWind.Playing then
		self._sounds.generalWind:Play()
	end
	if not self._sounds.generalWindB.Playing then
		self._sounds.generalWindB:Play()
	end
	if not self._sounds.heavyWind.Playing then
		self._sounds.heavyWind:Play()
	end
	if not self._sounds.heavyWindB.Playing then
		self._sounds.heavyWindB:Play()
	end
	if not self._sounds.rain.Playing then
		self._sounds.rain:Play()
	end
	if not self._sounds.rainB.Playing then
		self._sounds.rainB:Play()
	end

	tweenNumber(self, "generalWindVolume", self._sounds.generalWind, "Volume", generalVolume, 1.35)
	tweenNumber(self, "generalWindBVolume", self._sounds.generalWindB, "Volume", generalVolume * 0.82, 1.35)
	tweenNumber(self, "heavyWindVolume", self._sounds.heavyWind, "Volume", heavyVolume, 1.35)
	tweenNumber(self, "heavyWindBVolume", self._sounds.heavyWindB, "Volume", heavyVolume * 0.82, 1.35)
	tweenNumber(self, "rainVolume", self._sounds.rain, "Volume", rainVolume, 1.2)
	tweenNumber(self, "rainBVolume", self._sounds.rainB, "Volume", rainVolume * 0.86, 1.2)
end

function NatureAudio:SetWindEnabled(enabled: boolean)
	if self._windEnabled == enabled then
		return
	end

	self._windEnabled = enabled
	if enabled then
		if self._weather then
			self:ApplyWeather(self._weather)
		end
		return
	end

	tweenNumber(self, 'generalWindVolume', self._sounds.generalWind, 'Volume', 0, 0.45)
	tweenNumber(self, 'generalWindBVolume', self._sounds.generalWindB, 'Volume', 0, 0.45)
	tweenNumber(self, 'heavyWindVolume', self._sounds.heavyWind, 'Volume', 0, 0.45)
	tweenNumber(self, 'heavyWindBVolume', self._sounds.heavyWindB, 'Volume', 0, 0.45)
	tweenNumber(self, 'gustVolume', self._sounds.gust, 'Volume', 0, 0.35)
end

function NatureAudio:SetEnvironmentalAudioEnabled(enabled: boolean)
	if self._environmentAudioEnabled == enabled then
		return
	end

	self._environmentAudioEnabled = enabled
	if enabled then
		if self._weather then
			self:ApplyWeather(self._weather)
		end
		return
	end

	tweenNumber(self, 'rainVolume', self._sounds.rain, 'Volume', 0, 0.45)
	tweenNumber(self, 'rainBVolume', self._sounds.rainB, 'Volume', 0, 0.45)
	tweenNumber(self, 'birdsVolume', self._sounds.birds, 'Volume', 0, 0.35)
end

function NatureAudio:_maintainWindLoop(name: string, primary: Sound, secondary: Sound, length: number)
	local key = name .. "Swap"
	if primary.TimeLength > 0 then
		length = primary.TimeLength
	end

	local shouldSwap = primary.TimePosition >= math.max(length - 2.5, length * 0.88)
	if shouldSwap and not self._loopSwap[key] then
		self._loopSwap[key] = true
		secondary.TimePosition = 0
		if not secondary.Playing then
			secondary:Play()
		end
		task.delay(2.45, function()
			if primary.Parent then
				primary.TimePosition = 0
			end
			self._loopSwap[key] = false
		end)
	elseif primary.TimePosition < 2 then
		self._loopSwap[key] = false
	end
end

function NatureAudio:_maybePlayGust(now: number)
	if not self._windEnabled then
		return
	end

	local weather = self._weather
	if not weather or weather.windPower < 0.45 or now - self._lastGustAt < NATURE_SOUNDS.WindGust.minGap then
		return
	end

	local chance = math.clamp(weather.windPower * weather.windSpeed / 900, 0.01, 0.08)
	if math.random() > chance then
		return
	end

	self._lastGustAt = now
	local gust = self._sounds.gust
	gust.TimePosition = 0
	gust.Volume = 0
	gust:Play()
	tween(gust, 0.4, { Volume = 0.3 + weather.windPower * 0.45 * math.clamp(self._exposure, 0.45, 1) })
	task.delay(math.max(0.5, NATURE_SOUNDS.WindGust.length - 0.5), function()
		if gust.Parent then
			tween(gust, 0.55, { Volume = 0 })
		end
	end)
end

function NatureAudio:_maybePlayBirds(now: number)
	if not self._environmentAudioEnabled then
		return
	end

	local weather = self._weather
	if not weather or weather.rainIntensity > 0.15 or weather.windPower > 0.7 or self._exposure < 0.45 or now - self._lastBirdAt < NATURE_SOUNDS.BirdCoo.minGap then
		return
	end

	if math.random() > 0.16 * self._exposure then
		return
	end

	self._lastBirdAt = now
	local birds = self._sounds.birds
	birds.TimePosition = 0
	birds.Volume = 0
	birds:Play()
	tween(birds, 0.7, { Volume = 0.035 + self._exposure * 0.075 })
	task.delay(math.max(0.5, NATURE_SOUNDS.BirdCoo.length - 0.6), function()
		if birds.Parent then
			tween(birds, 0.7, { Volume = 0 })
		end
	end)
end

function NatureAudio:GetExposure(): number
	return self._exposure
end

function NatureAudio:GetRainExposure(): number
	local roofBlocked = self._roofCover ^ 1.7
	local sideLeak = self._wallOpen * 0.18
	return math.clamp((1 - roofBlocked) * 0.82 + sideLeak, 0.06, 1)
end

function NatureAudio:_loop()
	while not self._destroyed do
		local exposure, roofCover, wallOpen = self:_measureExposure()
		self._exposure += (exposure - self._exposure) * 0.18
		self._roofCover += (roofCover - self._roofCover) * 0.24
		self._wallOpen += (wallOpen - self._wallOpen) * 0.2
		self:_applyMuffle(self._exposure)
		if self._weather then
			self:ApplyWeather(self._weather)
		end
		self:_maintainWindLoop("GeneralWind", self._sounds.generalWind, self._sounds.generalWindB, NATURE_SOUNDS.GeneralWind.length)
		self:_maintainWindLoop("HeavyWind", self._sounds.heavyWind, self._sounds.heavyWindB, NATURE_SOUNDS.HeavyWind.length)
		self:_maintainWindLoop("RainBed", self._sounds.rain, self._sounds.rainB, RAIN_LOOP_LENGTH)

		local now = os.clock()
		self:_maybePlayGust(now)
		self:_maybePlayBirds(now)
		task.wait(1)
	end
end

function NatureAudio:Destroy()
	self._destroyed = true
	self._folder:Destroy()
end

return NatureAudio
