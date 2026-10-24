--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local EnvironmentDefinitions = require(ReplicatedStorage.Shared.Game.Environment.EnvironmentDefinitions)
local EnvironmentExposure = require(script.Parent.EnvironmentExposure)

local NatureAudio = {}

local NATURE_SOUNDS = EnvironmentDefinitions.NatureSounds
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
	TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), goals)
		:Play()
end

local function tweenNumber(
	State: any,
	key: string,
	instance: Instance,
	property: string,
	value: number,
	duration: number
)
	local last = State._targets[key]
	if last and math.abs(last - value) < 0.025 then
		return
	end

	State._targets[key] = value
	tween(instance, duration, {
		[property] = value,
	})
end

function NatureAudio.Init(exposureResource: any?)
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

	NatureAudio._folder = folder
	NatureAudio._exposureResource = exposureResource or EnvironmentExposure.Init()
	NatureAudio._sounds = {
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
	}
	NatureAudio._weather = nil
	NatureAudio._windEnabled = true
	NatureAudio._environmentAudioEnabled = true
	NatureAudio._exposure = 1
	NatureAudio._roofCover = 0
	NatureAudio._wallOpen = 1
	NatureAudio._destroyed = false
	NatureAudio._lastGustAt = -math.huge
	NatureAudio._lastBirdAt = -math.huge
	NatureAudio._targets = {}
	NatureAudio._loopSwap = {}

	task.spawn(function()
		NatureAudio._loop()
	end)

	return NatureAudio
end

function NatureAudio._measureExposure(): (number, number, number)
	local state = NatureAudio._exposureResource.Sample()
	return state.exposure, state.roofCover, state.wallOpen
end

function NatureAudio._applyMuffle(exposure: number)
	local indoor = math.clamp(NatureAudio._roofCover * 0.78 + (1 - NatureAudio._wallOpen) * 0.22, 0, 1)
	for index, sound in
		{
			NatureAudio._sounds.generalWind,
			NatureAudio._sounds.generalWindB,
			NatureAudio._sounds.heavyWind,
			NatureAudio._sounds.heavyWindB,
			NatureAudio._sounds.rain,
			NatureAudio._sounds.rainB,
			NatureAudio._sounds.gust,
			NatureAudio._sounds.birds,
		}
	do
		local eq = sound:FindFirstChild("ExposureMuffle")
		local rv = sound:FindFirstChild("ExposureRoom")
		if eq and eq:IsA("EqualizerSoundEffect") then
			tweenNumber(NatureAudio, "eqHigh" .. index, eq, "HighGain", -34 * indoor, 0.8)
			tweenNumber(NatureAudio, "eqMid" .. index, eq, "MidGain", -14 * indoor, 0.8)
			tweenNumber(NatureAudio, "eqLow" .. index, eq, "LowGain", -4 * indoor, 0.8)
		end
		if rv and rv:IsA("ReverbSoundEffect") then
			tweenNumber(NatureAudio, "rvWet" .. index, rv, "WetLevel", -80 + indoor * 62, 0.8)
			tweenNumber(NatureAudio, "rvDecay" .. index, rv, "DecayTime", 0.25 + indoor * 1.1, 0.8)
		end
	end
end

function NatureAudio.ApplyWeather(weather)
	NatureAudio._weather = weather
	local exposure = NatureAudio._exposure
	local windPresence = math.clamp(weather.windSpeed / 38, 0, 1) * math.clamp(weather.windPower, 0, 1)
	local exposureVolume = math.clamp(WIND_VOLUME.IndoorFloor + exposure * (1 - WIND_VOLUME.IndoorFloor), 0, 1)
	local heavyPresence = math.clamp((weather.windSpeed - 15) / 24, 0, 1) * math.clamp(weather.windPower, 0, 1)
	local rainExposure = NatureAudio.GetRainExposure()
	local windAudioScale = if NatureAudio._windEnabled then 1 else 0
	local environmentAudioScale = if NatureAudio._environmentAudioEnabled then 1 else 0
	local generalVolume = math.clamp(
		WIND_VOLUME.GeneralBase + windPresence * WIND_VOLUME.GeneralWindScale,
		0,
		WIND_VOLUME.GeneralMax
	) * exposureVolume * windAudioScale
	local heavyVolume = math.clamp(heavyPresence * WIND_VOLUME.HeavyScale, 0, WIND_VOLUME.HeavyMax)
		* exposureVolume
		* windAudioScale
	local rainVolume = math.clamp(weather.rainIntensity * (0.7 + weather.windPower * 0.24), 0, 1.25)
		* math.clamp(0.18 + rainExposure * 0.82, 0, 1)
		* environmentAudioScale

	if not NatureAudio._sounds.generalWind.Playing then
		NatureAudio._sounds.generalWind:Play()
	end
	if not NatureAudio._sounds.generalWindB.Playing then
		NatureAudio._sounds.generalWindB:Play()
	end
	if not NatureAudio._sounds.heavyWind.Playing then
		NatureAudio._sounds.heavyWind:Play()
	end
	if not NatureAudio._sounds.heavyWindB.Playing then
		NatureAudio._sounds.heavyWindB:Play()
	end
	if not NatureAudio._sounds.rain.Playing then
		NatureAudio._sounds.rain:Play()
	end
	if not NatureAudio._sounds.rainB.Playing then
		NatureAudio._sounds.rainB:Play()
	end

	tweenNumber(NatureAudio, "generalWindVolume", NatureAudio._sounds.generalWind, "Volume", generalVolume, 1.35)
	tweenNumber(
		NatureAudio,
		"generalWindBVolume",
		NatureAudio._sounds.generalWindB,
		"Volume",
		generalVolume * 0.82,
		1.35
	)
	tweenNumber(NatureAudio, "heavyWindVolume", NatureAudio._sounds.heavyWind, "Volume", heavyVolume, 1.35)
	tweenNumber(NatureAudio, "heavyWindBVolume", NatureAudio._sounds.heavyWindB, "Volume", heavyVolume * 0.82, 1.35)
	tweenNumber(NatureAudio, "rainVolume", NatureAudio._sounds.rain, "Volume", rainVolume, 1.2)
	tweenNumber(NatureAudio, "rainBVolume", NatureAudio._sounds.rainB, "Volume", rainVolume * 0.86, 1.2)
end

function NatureAudio.SetWindEnabled(enabled: boolean)
	if NatureAudio._windEnabled == enabled then
		return
	end

	NatureAudio._windEnabled = enabled
	if enabled then
		if NatureAudio._weather then
			NatureAudio.ApplyWeather(NatureAudio._weather)
		end
		return
	end

	tweenNumber(NatureAudio, "generalWindVolume", NatureAudio._sounds.generalWind, "Volume", 0, 0.45)
	tweenNumber(NatureAudio, "generalWindBVolume", NatureAudio._sounds.generalWindB, "Volume", 0, 0.45)
	tweenNumber(NatureAudio, "heavyWindVolume", NatureAudio._sounds.heavyWind, "Volume", 0, 0.45)
	tweenNumber(NatureAudio, "heavyWindBVolume", NatureAudio._sounds.heavyWindB, "Volume", 0, 0.45)
	tweenNumber(NatureAudio, "gustVolume", NatureAudio._sounds.gust, "Volume", 0, 0.35)
end

function NatureAudio.SetEnvironmentalAudioEnabled(enabled: boolean)
	if NatureAudio._environmentAudioEnabled == enabled then
		return
	end

	NatureAudio._environmentAudioEnabled = enabled
	if enabled then
		if NatureAudio._weather then
			NatureAudio.ApplyWeather(NatureAudio._weather)
		end
		return
	end

	tweenNumber(NatureAudio, "rainVolume", NatureAudio._sounds.rain, "Volume", 0, 0.45)
	tweenNumber(NatureAudio, "rainBVolume", NatureAudio._sounds.rainB, "Volume", 0, 0.45)
	tweenNumber(NatureAudio, "birdsVolume", NatureAudio._sounds.birds, "Volume", 0, 0.35)
end

function NatureAudio._maintainWindLoop(name: string, primary: Sound, secondary: Sound, length: number)
	local key = name .. "Swap"
	if primary.TimeLength > 0 then
		length = primary.TimeLength
	end

	local shouldSwap = primary.TimePosition >= math.max(length - 2.5, length * 0.88)
	if shouldSwap and not NatureAudio._loopSwap[key] then
		NatureAudio._loopSwap[key] = true
		secondary.TimePosition = 0
		if not secondary.Playing then
			secondary:Play()
		end
		task.delay(2.45, function()
			if primary.Parent then
				primary.TimePosition = 0
			end
			NatureAudio._loopSwap[key] = false
		end)
	elseif primary.TimePosition < 2 then
		NatureAudio._loopSwap[key] = false
	end
end

function NatureAudio._maybePlayGust(now: number)
	if not NatureAudio._windEnabled then
		return
	end

	local weather = NatureAudio._weather
	if not weather or weather.windPower < 0.45 or now - NatureAudio._lastGustAt < NATURE_SOUNDS.WindGust.minGap then
		return
	end

	local chance = math.clamp(weather.windPower * weather.windSpeed / 900, 0.01, 0.08)
	if math.random() > chance then
		return
	end

	NatureAudio._lastGustAt = now
	local gust = NatureAudio._sounds.gust
	gust.TimePosition = 0
	gust.Volume = 0
	gust:Play()
	tween(gust, 0.4, { Volume = 0.3 + weather.windPower * 0.45 * math.clamp(NatureAudio._exposure, 0.45, 1) })
	task.delay(math.max(0.5, NATURE_SOUNDS.WindGust.length - 0.5), function()
		if gust.Parent then
			tween(gust, 0.55, { Volume = 0 })
		end
	end)
end

function NatureAudio._maybePlayBirds(now: number)
	if not NatureAudio._environmentAudioEnabled then
		return
	end

	local weather = NatureAudio._weather
	if
		not weather
		or weather.rainIntensity > 0.15
		or weather.windPower > 0.7
		or NatureAudio._exposure < 0.45
		or now - NatureAudio._lastBirdAt < NATURE_SOUNDS.BirdCoo.minGap
	then
		return
	end

	if math.random() > 0.16 * NatureAudio._exposure then
		return
	end

	NatureAudio._lastBirdAt = now
	local birds = NatureAudio._sounds.birds
	birds.TimePosition = 0
	birds.Volume = 0
	birds:Play()
	tween(birds, 0.7, { Volume = 0.035 + NatureAudio._exposure * 0.075 })
	task.delay(math.max(0.5, NATURE_SOUNDS.BirdCoo.length - 0.6), function()
		if birds.Parent then
			tween(birds, 0.7, { Volume = 0 })
		end
	end)
end

function NatureAudio.GetExposure(): number
	return NatureAudio._exposure
end

function NatureAudio.GetRainExposure(): number
	local roofBlocked = NatureAudio._roofCover ^ 1.7
	local sideLeak = NatureAudio._wallOpen * 0.18
	return math.clamp((1 - roofBlocked) * 0.82 + sideLeak, 0.06, 1)
end

function NatureAudio._loop()
	while not NatureAudio._destroyed do
		local exposure, roofCover, wallOpen = NatureAudio._measureExposure()
		NatureAudio._exposure += (exposure - NatureAudio._exposure) * 0.18
		NatureAudio._roofCover += (roofCover - NatureAudio._roofCover) * 0.24
		NatureAudio._wallOpen += (wallOpen - NatureAudio._wallOpen) * 0.2
		NatureAudio._applyMuffle(NatureAudio._exposure)
		if NatureAudio._weather then
			NatureAudio.ApplyWeather(NatureAudio._weather)
		end
		NatureAudio._maintainWindLoop(
			"GeneralWind",
			NatureAudio._sounds.generalWind,
			NatureAudio._sounds.generalWindB,
			NATURE_SOUNDS.GeneralWind.length
		)
		NatureAudio._maintainWindLoop(
			"HeavyWind",
			NatureAudio._sounds.heavyWind,
			NatureAudio._sounds.heavyWindB,
			NATURE_SOUNDS.HeavyWind.length
		)
		NatureAudio._maintainWindLoop("RainBed", NatureAudio._sounds.rain, NatureAudio._sounds.rainB, RAIN_LOOP_LENGTH)

		local now = os.clock()
		NatureAudio._maybePlayGust(now)
		NatureAudio._maybePlayBirds(now)
		task.wait(1)
	end
end

function NatureAudio.Destroy()
	NatureAudio._destroyed = true
	NatureAudio._folder:Destroy()
end

return NatureAudio
