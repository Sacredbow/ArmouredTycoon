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
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const EnvironmentShared = require(ReplicatedStorage.EnvironmentShared)
const EnvironmentSchedule = require(script.EnvironmentSchedule)
const LightningModule = require(script.LightningModule)
const ECS = require(ReplicatedStorage.ECS)

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

local function BlendWeather(Base: LightingPreset, Weather: EnvironmentShared.WeatherState?, LightingWeight: number?): LightingPreset
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

local function ToWeatherPacket(State: EnvironmentShared.WeatherState): WeatherPacketPayload
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
EnvironmentService.__index = EnvironmentService

local LightsAreOn = false

--// Constructor

type EnvironmentDependencies = {
	LightingPackage: Instance?,
	Props: Instance,
	Packets: any,
	BuildAssemble: any?,
}

export type EnvironmentService = typeof(setmetatable({} :: {
	LightingPackage: Instance?,
	Props: Instance,
	Packets: any,
	BuildAssemble: any?,
	WeatherSchedule: EnvironmentSchedule.EnvironmentSchedule,
	CurrentWeather: EnvironmentShared.WeatherState,
	WeatherLightingWeight: number,
	NightStormActive: boolean,
	_WeatherLightingTweenToken: number?,
}, EnvironmentService))

function EnvironmentService.new(Dependencies: EnvironmentDependencies): EnvironmentService
	const self = setmetatable({}, EnvironmentService) :: EnvironmentService

	self.LightingPackage = Dependencies.LightingPackage
	self.Props = Dependencies.Props
	self.Packets = Dependencies.Packets
	self.BuildAssemble = Dependencies.BuildAssemble
	self.WeatherSchedule = EnvironmentSchedule.new()
	self.CurrentWeather = self.WeatherSchedule:GetCurrent()
	self.WeatherLightingWeight = self.CurrentWeather.lightingWeight or 0
	self.NightStormActive = false
	self._WeatherLightingTweenToken = nil

	return self
end

--// Public API

function EnvironmentService:Init()
	self:_InitDayNight()
	self:_InitWeather()
	self:_InitShootingStar()
end

--// Internal Methods — Day/Night

function EnvironmentService:_InitDayNight()
	ECS.createEntity({
		Name = "EnvironmentClock",
		EnvironmentClock = {
			service = self,
			currentTime = DAY_START_HOUR,
			timeSpeed = TIME_SPEED,
		},
	})
end

function EnvironmentService:_UpdateLighting(Hour: number)
	Hour = Hour % 24
	Lighting.ClockTime = Hour

	if Hour < DAWN_START then
		self:_ApplyLighting(Blend(DayNightPresets.Night, DayNightPresets.Dawn, Hour / DAWN_START))
		self:_SetStreetLights(true)
	elseif Hour < DAY_START then
		self:_ApplyLighting(Blend(DayNightPresets.Dawn, DayNightPresets.Day, (Hour - DAWN_START) / (DAY_START - DAWN_START)))
		self:_SetStreetLights(false)
	elseif Hour < DUSK_START then
		self:_ApplyLighting(DayNightPresets.Day)
		self:_SetStreetLights(false)
	elseif Hour < NIGHT_START then
		self:_ApplyLighting(Blend(DayNightPresets.Day, DayNightPresets.Dusk, (Hour - DUSK_START) / (NIGHT_START - DUSK_START)))
		self:_SetStreetLights(true)
	else
		self:_ApplyLighting(Blend(DayNightPresets.Dusk, DayNightPresets.Night, (Hour - NIGHT_START) / (24 - NIGHT_START)))
		self:_SetStreetLights(true)
	end
end

function EnvironmentService:_ApplyLighting(Props: LightingPreset)
	const ResolvedProps = BlendWeather(Props, self.CurrentWeather, self.WeatherLightingWeight)

	Lighting.Brightness = ResolvedProps.Brightness
	Lighting.OutdoorAmbient = ResolvedProps.OutdoorAmbient
	Lighting.Ambient = ResolvedProps.Ambient
	Lighting.FogEnd = ResolvedProps.FogEnd
end

--// Internal Methods — Street Lights

function EnvironmentService:_SetStreetLights(Enabled: boolean)
	if LightsAreOn == Enabled then
		return
	end
	LightsAreOn = Enabled

	for _, Prop in self.Props:GetChildren() do
		if Prop.Name == "StreetLights" and Prop:IsA("Model") then
			const LightGroups = Prop:GetChildren()
			for GroupIndex, Item in LightGroups do
				if not (Item:IsA("Model") or Item:IsA("Folder") or Item:IsA("BasePart")) then
					continue
				end

				const DelayTime = (GroupIndex - 1) * STREET_LIGHT_STAGGER
				SetLightEffects(Item, false)

				if Enabled and self.BuildAssemble then
					self.BuildAssemble.Play(Item, function()
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
				elseif self.BuildAssemble then
					self.BuildAssemble.Deassemble(Item, nil, {
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

function EnvironmentService:_InitWeather()
	self:_BroadcastWeather(nil :: Player?)
	Players.PlayerAdded:Connect(function(Player: Player)
		task.defer(function()
			self:_BroadcastWeather(Player)
		end)
	end)

	ECS.createEntity({
		Name = "EnvironmentWeatherTick",
		ScheduledTask = {
			delay = WEATHER_TICK_INTERVAL,
			repeatEvery = WEATHER_TICK_INTERVAL,
			elapsed = 0,
			callback = function()
				self:_UpdateWeather()
			end,
		},
	})
end

function EnvironmentService:_BroadcastWeather(Player: Player?)
	if not self.Packets then
		return
	end

	const Payload = ToWeatherPacket(self.CurrentWeather)
	if Player then
		self.Packets.packets.Weather.sendTo(Payload, Player)
	else
		self.Packets.packets.Weather.sendToAll(Payload)
	end
end

function EnvironmentService:_SetWeather(Weather: EnvironmentShared.WeatherState)
	const PreviousWeight = self.WeatherLightingWeight
	const TargetWeight = Weather.lightingWeight or 0

	self.CurrentWeather = Weather
	self._WeatherLightingTweenToken = (self._WeatherLightingTweenToken or 0) + 1
	const TweenToken = self._WeatherLightingTweenToken
	const StartedAt = os.clock()

	task.spawn(function()
		while TweenToken == self._WeatherLightingTweenToken do
			const Alpha = math_clamp((os.clock() - StartedAt) / WEATHER_LIGHTING_TWEEN_TIME, 0, 1)
			const EasedAlpha = 1 - (1 - Alpha) * (1 - Alpha)
			self.WeatherLightingWeight = Lerp(PreviousWeight, TargetWeight, EasedAlpha)

			if Alpha >= 1 then
				break
			end

			task.wait(0.05)
		end

		if TweenToken == self._WeatherLightingTweenToken then
			self.WeatherLightingWeight = TargetWeight
		end
	end)
end

--// Internal Methods — Shooting Stars

function EnvironmentService:_InitShootingStar()
	ECS.createEntity({
		Name = "EnvironmentShootingStarTick",
		ScheduledTask = {
			delay = SHOOTING_STAR_INTERVAL,
			repeatEvery = SHOOTING_STAR_INTERVAL,
			elapsed = 0,
			callback = function()
				self:_MaybeSpawnShootingStar()
			end,
		},
	})
end

function EnvironmentService:_MaybeSpawnShootingStar()
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

	if self.Packets then
		self.Packets.packets.ShootingStar.sendToAll({
			startPosition = StartPosition,
			direction = Direction,
			impact = Impact,
		})
	end
end

function EnvironmentService:_UpdateWeather()
	if self.NightStormActive then
		self.NightStormActive = false
		self:_SetWeather(self.WeatherSchedule:GetCurrent())
		self:_BroadcastWeather(nil)
	elseif self.WeatherSchedule:ShouldAdvance() then
		self:_SetWeather(self.WeatherSchedule:Next())
		self:_BroadcastWeather(nil)
	end

	local Weather: EnvironmentShared.WeatherState = self.CurrentWeather
	if math_random() < Weather.thunderChance then
		LightningModule.StartStorm(Vector3.new(50, 0, 0), THUNDER_RADIUS, math_clamp(Weather.duration * 0.35, 25, 90))
	end
end

return EnvironmentService

