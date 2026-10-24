--!strict

local WindLines = require(script.WindLines)
local WindShake = require(script.WindShake)

local WindConstructor = {}

local started = false

local function getPressure(weather): number
	return math.clamp((weather.windSpeed * weather.windPower) / 38, 0, 1.35)
end

function WindConstructor.Start(weather)
	if started then
		return
	end

	local pressure = getPressure(weather)
	started = true
	WindLines:Init({
		Direction = weather.windDirection,
		Speed = weather.windSpeed * (1.2 + pressure * 0.55),
		Lifetime = 2.2,
		SpawnRate = math.floor(20 + pressure * 90),
	})

	WindShake:SetDefaultSettings({
		WindDirection = weather.windDirection,
		WindPower = math.max(weather.windPower, 0.18) * (1 + pressure * 0.45),
		WindSpeed = weather.windSpeed * (1.15 + pressure * 0.35),
	})
	WindShake:Init()
end

function WindConstructor.Apply(weather)
	local pressure = getPressure(weather)
	WindLines.Direction = weather.windDirection
	WindLines.Speed = weather.windSpeed * (1.2 + pressure * 0.55)
	WindLines.Lifetime = 1.8 + pressure * 0.9
	WindLines.SpawnRate = math.floor(math.clamp(18 + weather.windSpeed * weather.windPower * 3.8, 10, 170))

	WindShake:UpdateAllObjectSettings({
		WindDirection = weather.windDirection,
		WindPower = math.max(weather.windPower, 0.18) * (1 + pressure * 0.45),
		WindSpeed = weather.windSpeed * (1.15 + pressure * 0.35),
	})
	WindShake:SetDefaultSettings({
		WindDirection = weather.windDirection,
		WindPower = math.max(weather.windPower, 0.18) * (1 + pressure * 0.45),
		WindSpeed = weather.windSpeed * (1.15 + pressure * 0.35),
	})
end

return WindConstructor
