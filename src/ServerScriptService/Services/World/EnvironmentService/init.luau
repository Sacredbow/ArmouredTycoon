--!strict
--[[
	@class EnvironmentService

	@desc
	Server-side day/night cycle and weather scheduler.
	- Drives Lighting.ClockTime through an ECS EnvironmentClock entity.
	- Blends between dawn/day/dusk/night lighting presets.
	- Schedules weather changes via EnvironmentSchedule.
	- Broadcasts the current weather state over the Weather packet.
	- Animates street lights on/off via BuildAssemble.
	- Triggers lightning storms during weather with thunderChance.
]]

--// Services

const Lighting = game:GetService("Lighting")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const EnvironmentDefinitions = require(ReplicatedStorage.Shared.Game.Environment.EnvironmentDefinitions)
const EnvironmentSchedule = require(script.EnvironmentSchedule)
const LightningModule = require(script.LightningModule)
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const Observers = require(ReplicatedStorage.Packages.Observers)

--// Constants

const FULL_DAY_LENGTH = 600
const TIME_SPEED = 24 / FULL_DAY_LENGTH

const DAWN_START = 5
const DAY_START = 6
const DUSK_START = 16
const NIGHT_START = 17

const WEATHER_LIGHTING_TWEEN_TIME = 4
const STREET_LIGHT_STAGGER = 0.18
const WEATHER_TICK_INTERVAL = 12
const THUNDER_RADIUS = 400
const DAY_START_HOUR = 6

const SHOOTING_STAR_INTERVAL = 25
const SHOOTING_STAR_CHANCE = 0.6
const SHOOTING_STAR_IMPACT_CHANCE = 0.35
const SHOOTING_STAR_ALTITUDE_MIN = 700
const SHOOTING_STAR_ALTITUDE_MAX = 1200
const SHOOTING_STAR_RADIUS = 900

--// Types

type LightingPreset = {
	Brightness: number,
	OutdoorAmbient: Color3,
	Ambient: Color3,
	FogEnd: number,
}

type WeatherPacketPayload = {
	["type"]: string,
	duration: number,
	windDirection: Vector3,
	windSpeed: number,
	windPower: number,
	rainIntensity: number,
	thunderChance: number,
	lightingWeight: number,
}

--// Lighting Presets

const DayNightPresets: { [string]: LightingPreset } = {
	Night = {
		Brightness = 0.85,
		OutdoorAmbient = Color3.fromRGB(92, 100, 132),
		Ambient = Color3.fromRGB(118, 126, 164),
		FogEnd = 5200,
	},
	Dawn = {
		Brightness = 1,
		OutdoorAmbient = Color3.fromRGB(100, 80, 70),
		Ambient = Color3.fromRGB(150, 120, 100),
		FogEnd = 4000,
	},
	Day = {
		Brightness = 1.1,
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		Ambient = Color3.fromRGB(255, 255, 255),
		FogEnd = 7000,
	},
	Dusk = {
		Brightness = 1.05,
		OutdoorAmbient = Color3.fromRGB(112, 116, 136),
		Ambient = Color3.fromRGB(166, 164, 178),
		FogEnd = 5200,
	},
}

const WeatherPresets: { [string]: LightingPreset } = {
	Clear = {
		Brightness = 1.1,
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		Ambient = Color3.fromRGB(255, 255, 255),
		FogEnd = 7000,
	},
	Cloudy = {
		Brightness = 1,
		OutdoorAmbient = Color3.fromRGB(116, 122, 130),
		Ambient = Color3.fromRGB(188, 194, 204),
		FogEnd = 5600,
	},
	Rain = {
		Brightness = 0.92,
		OutdoorAmbient = Color3.fromRGB(98, 108, 122),
		Ambient = Color3.fromRGB(154, 168, 184),
		FogEnd = 3800,
	},
	Storm = {
		Brightness = 0.78,
		OutdoorAmbient = Color3.fromRGB(78, 88, 108),
		Ambient = Color3.fromRGB(126, 140, 166),
		FogEnd = 3000,
	},
	Fog = {
		Brightness = 0.94,
		OutdoorAmbient = Color3.fromRGB(132, 134, 136),
		Ambient = Color3.fromRGB(196, 198, 198),
		FogEnd = 1250,
	},
}

--// Micro-Optimisations

const math_clamp = math.clamp
const math_random = math.random

--// Internal Utilities

local function Lerp(A: number, B: number, T: number): number
	return A + (B - A) * T
end

local function LerpColor(A: Color3, B: Color3, T: number): Color3
	return Color3.new(Lerp(A.R, B.R, T), Lerp(A.G, B.G, T), Lerp(A.B, B.B, T))
end

local function Blend(A: LightingPreset, B: LightingPreset, T: number): LightingPreset
	return {
		Brightness = Lerp(A.Brightness, B.Brightness, T),
		OutdoorAmbient = LerpColor(A.OutdoorAmbient, B.OutdoorAmbient, T),
		Ambient = LerpColor(A.Ambient, B.Ambient, T),
		FogEnd = Lerp(A.FogEnd, B.FogEnd, T),
	}
end

local function BlendWeather(Base: LightingPreset, Weather: EnvironmentDefinitions.WeatherState?, LightingWeight: number?): LightingPreset
	if not Weather then
		return Base
	end

	const Target = WeatherPresets[Weather["type"]]
	if not Target then
		return Base
	end

	const Weight = math_clamp(LightingWeight or Weather.lightingWeight or 0, 0, 1)
	return Blend(Base, Target, Weight)
end

local function ToWeatherPacket(State: EnvironmentDefinitions.WeatherState): WeatherPacketPayload
	return {
		["type"] = State["type"],
		duration = State.duration,
		windDirection = State.windDirection,
		windSpeed = State.windSpeed,
		windPower = State.windPower,
		rainIntensity = State.rainIntensity,
		thunderChance = State.thunderChance,
		lightingWeight = State.lightingWeight,
	}
end

local function SetLightEffects(Item: Instance, Enabled: boolean)
	for _, Descendant in Item:GetDescendants() do
		if Descendant:IsA("SurfaceLight") then
			Descendant.Brightness = if Enabled then 1 else 0
			Descendant.Enabled = Enabled
			continue
		end

		if Descendant:IsA("PointLight") then
			Descendant.Enabled = Enabled
			continue
		end

		if Descendant:IsA("SpotLight") then
			Descendant.Enabled = Enabled
			continue
		end

		if Descendant:IsA("Beam") then
			Descendant.Enabled = Enabled
		end
	end
end

--// Module

local EnvironmentService = {}

local LightsAreOn = false
local Initialized = false

--// Constructor

type EnvironmentDependencies = { LightingPackage: Instance?, Props: Instance, Packets: any, BuildAssemble: any? }

function EnvironmentService.Configure(Dependencies: EnvironmentDependencies)
	EnvironmentService.LightingPackage = Dependencies.LightingPackage
	EnvironmentService.Props = Dependencies.Props
	EnvironmentService.Packets = Dependencies.Packets
	EnvironmentService.BuildAssemble = Dependencies.BuildAssemble
	EnvironmentService.WeatherSchedule = EnvironmentSchedule.Create()
	EnvironmentService.CurrentWeather = EnvironmentSchedule.GetCurrent(EnvironmentService.WeatherSchedule)
	EnvironmentService.WeatherLightingWeight = EnvironmentService.CurrentWeather.lightingWeight or 0
	EnvironmentService.NightStormActive = false
	EnvironmentService._WeatherLightingTweenToken = nil
	EnvironmentService._WeatherPlayerObserverStop = nil
	return EnvironmentService
end

--// Public API

function EnvironmentService.Start()
	if Initialized then
		return
	end

	Initialized = true
	EnvironmentService.InitDayNight()
	EnvironmentService.InitWeather()
	EnvironmentService.InitShootingStar()
end

--// Internal Methods — Day/Night

function EnvironmentService.UpdateLightingFromClock(Hour: number)
	EnvironmentService.UpdateLighting(Hour)
end

function EnvironmentService.UpdateWeatherActive()
	EnvironmentService.UpdateWeather()
end

function EnvironmentService.SpawnShootingStarActive()
	EnvironmentService.MaybeSpawnShootingStar()
end

function EnvironmentService.InitDayNight()
end

function EnvironmentService.UpdateLighting(Hour: number)
	Hour = Hour % 24
	Lighting.ClockTime = Hour

	if Hour < DAWN_START then
		EnvironmentService.ApplyLighting(Blend(DayNightPresets.Night, DayNightPresets.Dawn, Hour / DAWN_START))
		EnvironmentService.SetStreetLights(true)
	elseif Hour < DAY_START then
		EnvironmentService.ApplyLighting(Blend(DayNightPresets.Dawn, DayNightPresets.Day, (Hour - DAWN_START) / (DAY_START - DAWN_START)))
		EnvironmentService.SetStreetLights(false)
	elseif Hour < DUSK_START then
		EnvironmentService.ApplyLighting(DayNightPresets.Day)
		EnvironmentService.SetStreetLights(false)
	elseif Hour < NIGHT_START then
		EnvironmentService.ApplyLighting(Blend(DayNightPresets.Day, DayNightPresets.Dusk, (Hour - DUSK_START) / (NIGHT_START - DUSK_START)))
		EnvironmentService.SetStreetLights(true)
	else
		EnvironmentService.ApplyLighting(Blend(DayNightPresets.Dusk, DayNightPresets.Night, (Hour - NIGHT_START) / (24 - NIGHT_START)))
		EnvironmentService.SetStreetLights(true)
	end
end

function EnvironmentService.ApplyLighting(Props: LightingPreset)
	const ResolvedProps = BlendWeather(Props, EnvironmentService.CurrentWeather, EnvironmentService.WeatherLightingWeight)

	Lighting.Brightness = ResolvedProps.Brightness
	Lighting.OutdoorAmbient = ResolvedProps.OutdoorAmbient
	Lighting.Ambient = ResolvedProps.Ambient
	Lighting.FogEnd = ResolvedProps.FogEnd
end

--// Internal Methods — Street Lights

function EnvironmentService.SetStreetLights(Enabled: boolean)
	if LightsAreOn == Enabled then
		return
	end
	LightsAreOn = Enabled

	for _, Prop in EnvironmentService.Props:GetChildren() do
		if Prop.Name == "StreetLights" and Prop:IsA("Model") then
			const LightGroups = Prop:GetChildren()
			for GroupIndex, Item in LightGroups do
				if not (Item:IsA("Model") or Item:IsA("Folder") or Item:IsA("BasePart")) then
					continue
				end

				const DelayTime = (GroupIndex - 1) * STREET_LIGHT_STAGGER
				SetLightEffects(Item, false)

				if Enabled and EnvironmentService.BuildAssemble then
					EnvironmentService.BuildAssemble.Play(Item, function()
						SetLightEffects(Item, true)
					end, {
						includeHidden = true,
						timingScale = 1.35 + (GroupIndex % 3) * 0.18,
						pieceBudget = 54,
						maxPiecesPerPart = 3,
						creationBatchSize = 10,
						staggerPortion = 0.78,
						initialDelay = DelayTime,
						settleFade = 0.22,
					})
				elseif Enabled then
					SetLightEffects(Item, true)
					for _, Part in Item:GetDescendants() do
						if Part:IsA("BasePart") then
							Part.Transparency = 0
							Part.CanCollide = true
						end
					end
				elseif EnvironmentService.BuildAssemble then
					EnvironmentService.BuildAssemble.Deassemble(Item, nil, {
						includeHidden = true,
						timingScale = 0.9 + (GroupIndex % 2) * 0.15,
						pieceBudget = 42,
						maxPiecesPerPart = 2,
						creationBatchSize = 10,
						staggerPortion = 0.62,
					})
				else
					for _, Part in Item:GetDescendants() do
						if Part:IsA("BasePart") then
							Part.Transparency = 1
							Part.CanCollide = false
						end
					end
				end
			end
		end
	end
end

--// Internal Methods — Weather

function EnvironmentService.InitWeather()
	EnvironmentService.BroadcastWeather(nil :: Player?)
	EnvironmentService._WeatherPlayerObserverStop = Observers.observePlayer(function(player: Player)
		task.defer(function()
			EnvironmentService.BroadcastWeather(player)
		end)
	end)

	ECS.createEntity({
		Name = "EnvironmentWeatherTick",
		EnvironmentWeatherTick = {Remaining = WEATHER_TICK_INTERVAL, Interval = WEATHER_TICK_INTERVAL},
	})
end

function EnvironmentService.BroadcastWeather(Player: Player?)
	if not EnvironmentService.Packets then
		return
	end

	const Payload = ToWeatherPacket(EnvironmentService.CurrentWeather)
	if Player then
		EnvironmentService.Packets.packets.Weather.sendTo(Payload, Player)
	else
		EnvironmentService.Packets.packets.Weather.sendToAll(Payload)
	end
end

function EnvironmentService.SetWeather(Weather: EnvironmentDefinitions.WeatherState)
	const PreviousWeight = EnvironmentService.WeatherLightingWeight
	const TargetWeight = Weather.lightingWeight or 0

	EnvironmentService.CurrentWeather = Weather
	EnvironmentService._WeatherLightingTweenToken = (EnvironmentService._WeatherLightingTweenToken or 0) + 1
	const TweenToken = EnvironmentService._WeatherLightingTweenToken
	const StartedAt = os.clock()

	task.spawn(function()
		while TweenToken == EnvironmentService._WeatherLightingTweenToken do
			const Alpha = math_clamp((os.clock() - StartedAt) / WEATHER_LIGHTING_TWEEN_TIME, 0, 1)
			const EasedAlpha = 1 - (1 - Alpha) * (1 - Alpha)
			EnvironmentService.WeatherLightingWeight = Lerp(PreviousWeight, TargetWeight, EasedAlpha)

			if Alpha >= 1 then
				break
			end

			task.wait(0.05)
		end

		if TweenToken == EnvironmentService._WeatherLightingTweenToken then
			EnvironmentService.WeatherLightingWeight = TargetWeight
		end
	end)
end

--// Internal Methods — Shooting Stars

function EnvironmentService.InitShootingStar()
	ECS.createEntity({
		Name = "EnvironmentShootingStarTick",
		EnvironmentShootingStarTick = {Remaining = SHOOTING_STAR_INTERVAL, Interval = SHOOTING_STAR_INTERVAL},
	})
end

function EnvironmentService.MaybeSpawnShootingStar()
	local Hour = Lighting.ClockTime % 24
	local IsNight = Hour >= NIGHT_START or Hour < DAWN_START
	if not IsNight then
		return
	end

	--[[ RANDOMIZED SPAWN (commented out for consistent fixed spawn)
	if math_random() > SHOOTING_STAR_CHANCE then
		return
	end

	local Angle = math_random() * math.pi * 2
	local Radius = math_random() * SHOOTING_STAR_RADIUS
	local StartPosition = Vector3.new(
		math.cos(Angle) * Radius,
		math_random(SHOOTING_STAR_ALTITUDE_MIN, SHOOTING_STAR_ALTITUDE_MAX),
		math.sin(Angle) * Radius
	)

	local Impact = math_random() < SHOOTING_STAR_IMPACT_CHANCE
	local HorizontalAngle = math_random() * math.pi * 2
	local Direction: Vector3
	if Impact then
		-- Plunge toward the map.
		Direction = Vector3.new(
			math.cos(HorizontalAngle),
			-(0.5 + math_random() * 0.5),
			math.sin(HorizontalAngle)
		).Unit
	else
		-- Streak across the sky, mostly horizontal.
		Direction = Vector3.new(
			math.cos(HorizontalAngle),
			math_random() * 0.16 - 0.08,
			math.sin(HorizontalAngle)
		).Unit
	end
	]]

	-- Fixed spawn: always spawns at the same position, streaking across the sky.
	local StartPosition = Vector3.new(-600, 1000, 400)
	local Impact = false
	local Direction = Vector3.new(1, -0.05, 0.4).Unit

	if EnvironmentService.Packets then
		EnvironmentService.Packets.packets.ShootingStar.sendToAll({
			startPosition = StartPosition,
			direction = Direction,
			impact = Impact,
		})
	end
end

function EnvironmentService.UpdateWeather()
	if EnvironmentService.NightStormActive then
		EnvironmentService.NightStormActive = false
		EnvironmentService.SetWeather(EnvironmentSchedule.GetCurrent(EnvironmentService.WeatherSchedule))
		EnvironmentService.BroadcastWeather(nil)
	elseif EnvironmentSchedule.ShouldAdvance(EnvironmentService.WeatherSchedule) then
		EnvironmentService.SetWeather(EnvironmentSchedule.Next(EnvironmentService.WeatherSchedule))
		EnvironmentService.BroadcastWeather(nil)
	end

	local Weather: EnvironmentDefinitions.WeatherState = EnvironmentService.CurrentWeather
	if math_random() < Weather.thunderChance then
		LightningModule.StartStorm(Vector3.new(50, 0, 0), THUNDER_RADIUS, math_clamp(Weather.duration * 0.35, 25, 90))
	end
end

return EnvironmentService
