--!strict

local EnvironmentDefinitions = {}

export type WeatherKind = "Clear" | "Cloudy" | "Rain" | "Storm" | "Fog"

export type WeatherState = {
	["type"]: WeatherKind,
	duration: number,
	windDirection: Vector3,
	windSpeed: number,
	windPower: number,
	rainIntensity: number,
	thunderChance: number,
	lightingWeight: number,
}

export type NatureSoundConfig = {
	soundId: string,
	length: number,
	minGap: number,
}

EnvironmentDefinitions.Weather = {
	Clear = {
		["type"] = "Clear",
		duration = 360,
		windDirection = Vector3.new(0.8, 0, 0.25).Unit,
		windSpeed = 7,
		windPower = 0.15,
		rainIntensity = 0,
		thunderChance = 0,
		lightingWeight = 0,
	},
	Cloudy = {
		["type"] = "Cloudy",
		duration = 260,
		windDirection = Vector3.new(0.65, 0, -0.45).Unit,
		windSpeed = 13,
		windPower = 0.35,
		rainIntensity = 0,
		thunderChance = 0,
		lightingWeight = 0,
	},
	Rain = {
		["type"] = "Rain",
		duration = 210,
		windDirection = Vector3.new(0.45, -0.04, 0.75).Unit,
		windSpeed = 22,
		windPower = 0.62,
		rainIntensity = 0.72,
		thunderChance = 0.16,
		lightingWeight = 0.22,
	},
	Storm = {
		["type"] = "Storm",
		duration = 180,
		windDirection = Vector3.new(0.9, -0.08, -0.2).Unit,
		windSpeed = 38,
		windPower = 1,
		rainIntensity = 1,
		thunderChance = 0.42,
		lightingWeight = 0.32,
	},
	Fog = {
		["type"] = "Fog",
		duration = 240,
		windDirection = Vector3.new(-0.35, 0, 0.8).Unit,
		windSpeed = 5,
		windPower = 0.12,
		rainIntensity = 0,
		thunderChance = 0,
		lightingWeight = 0.08,
	},
} :: { [WeatherKind]: WeatherState }

EnvironmentDefinitions.Schedule = {
	"Clear",
	"Cloudy",
	"Rain",
	"Clear",
	"Fog",
	"Storm",
	"Rain",
	"Clear",
} :: { WeatherKind }

EnvironmentDefinitions.NatureSounds = {
	GeneralWind = {
		soundId = "rbxassetid://126470460855834",
		length = 42,
		minGap = 0,
	},
	WindGust = {
		soundId = "rbxassetid://72345818857167",
		length = 5,
		minGap = 10,
	},
	HeavyWind = {
		soundId = "rbxassetid://89190578966917",
		length = 48,
		minGap = 0,
	},
	BirdCoo = {
		soundId = "rbxassetid://110244903709169",
		length = 8,
		minGap = 10,
	},
} :: { [string]: NatureSoundConfig }

function EnvironmentDefinitions.getWeather(kind: WeatherKind): WeatherState
	return EnvironmentDefinitions.Weather[kind]
end

function EnvironmentDefinitions.getScheduledWeather(index: number): WeatherState
	local kind = EnvironmentDefinitions.Schedule[((index - 1) % #EnvironmentDefinitions.Schedule) + 1]
	return EnvironmentDefinitions.getWeather(kind)
end

return EnvironmentDefinitions
