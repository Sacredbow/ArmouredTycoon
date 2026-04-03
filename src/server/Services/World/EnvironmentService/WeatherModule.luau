--[[
NOT IN USE
THIS SCRIPT IS STILL IN WORK , DEVELOPED BY Sacredbow1
info: Weather script that handles 30+ different weathers.
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local GamePackage = ReplicatedStorage.GamePackage
local LightningModule = require(script.Parent.LightningModule)

local WeatherModule = {}
WeatherModule.__index = WeatherModule


local WeatherChangedEvent = ReplicatedStorage:FindFirstChild("WeatherChanged")
if not WeatherChangedEvent then
	WeatherChangedEvent = Instance.new("RemoteEvent")
	WeatherChangedEvent.Name = "WeatherChanged"
	WeatherChangedEvent.Parent = ReplicatedStorage
end



local WeatherTypes = {
	
	Clear = {
		Name = "Clear Skies",
		Duration = 300,
		Lighting = {
			Brightness = 2,
			OutdoorAmbient = Color3.fromRGB(150, 150, 150),
			Ambient = Color3.fromRGB(255, 255, 255),
			ClockTime = 12,
			FogEnd = 10000,
			FogColor = Color3.fromRGB(191, 191, 191),
		},
		Effects = function(weather)
			print("[WEATHER] Clear skies - Beautiful day!")
		end
	},

	Cloudy = {
		Name = "Cloudy",
		Duration = 240,
		Lighting = {
			Brightness = 1.5,
			OutdoorAmbient = Color3.fromRGB(100, 100, 120),
			Ambient = Color3.fromRGB(180, 180, 200),
			FogEnd = 5000,
			FogColor = Color3.fromRGB(200, 200, 210),
		},
		Effects = function(weather)
			weather:CreateClouds(50, Color3.fromRGB(220, 220, 230))
		end
	},

	Rain = {
		Name = "Rain",
		Duration = 180,
		Lighting = {
			Brightness = 1,
			OutdoorAmbient = Color3.fromRGB(80, 80, 100),
			Ambient = Color3.fromRGB(120, 120, 140),
			FogEnd = 2000,
			FogColor = Color3.fromRGB(150, 150, 160),
		},
		Effects = function(weather)
			weather:CreateRain(500, 50)
			weather:CreateClouds(30, Color3.fromRGB(100, 100, 110))
		end
	},

	Thunderstorm = {
		Name = "Thunderstorm",
		Duration = 200,
		Lighting = {
			Brightness = 0.5,
			OutdoorAmbient = Color3.fromRGB(60, 60, 80),
			Ambient = Color3.fromRGB(80, 80, 100),
			FogEnd = 1500,
			FogColor = Color3.fromRGB(100, 100, 110),
		},
		Effects = function(weather)
			weather:CreateRain(800, 60)
			weather:CreateLightningStorm(200, 300)
		end
	},

	Fog = {
		Name = "Heavy Fog",
		Duration = 220,
		Lighting = {
			Brightness = 1.2,
			OutdoorAmbient = Color3.fromRGB(120, 120, 130),
			Ambient = Color3.fromRGB(150, 150, 160),
			FogEnd = 200,
			FogColor = Color3.fromRGB(200, 200, 210),
		},
		Effects = function(weather)
			weather:CreateFogParticles()
		end
	},

	Snow = {
		Name = "Snowfall",
		Duration = 250,
		Lighting = {
			Brightness = 1.8,
			OutdoorAmbient = Color3.fromRGB(150, 160, 180),
			Ambient = Color3.fromRGB(220, 230, 255),
			FogEnd = 3000,
			FogColor = Color3.fromRGB(230, 235, 245),
		},
		Effects = function(weather)
			weather:CreateSnow(300, 15)
			weather:CreateClouds(40, Color3.fromRGB(240, 240, 250))
		end
	},

	Blizzard = {
		Name = "Blizzard",
		Duration = 180,
		Lighting = {
			Brightness = 0.8,
			OutdoorAmbient = Color3.fromRGB(120, 130, 150),
			Ambient = Color3.fromRGB(180, 190, 210),
			FogEnd = 500,
			FogColor = Color3.fromRGB(220, 225, 235),
		},
		Effects = function(weather)
			weather:CreateSnow(800, 40)
			weather:CreateWind(60)
		end
	},


	AuroraBorealis = {
		Name = "Aurora Borealis",
		Duration = 300,
		Lighting = {
			Brightness = 0.3,
			OutdoorAmbient = Color3.fromRGB(40, 80, 100),
			Ambient = Color3.fromRGB(80, 120, 140),
			ClockTime = 1,
			FogEnd = 8000,
			FogColor = Color3.fromRGB(20, 40, 60),
		},
		Effects = function(weather)
			weather:CreateAurora()
		end
	},

	MeteorShower = {
		Name = "Meteor Shower",
		Duration = 200,
		Lighting = {
			Brightness = 0.2,
			OutdoorAmbient = Color3.fromRGB(30, 30, 50),
			Ambient = Color3.fromRGB(60, 60, 80),
			ClockTime = 0,
			FogEnd = 10000,
		},
		Effects = function(weather)
			weather:CreateMeteorShower(40)
		end
	},

	CrystalRain = {
		Name = "Crystal Rain",
		Duration = 240,
		Lighting = {
			Brightness = 1.5,
			OutdoorAmbient = Color3.fromRGB(150, 180, 220),
			Ambient = Color3.fromRGB(200, 220, 255),
			FogEnd = 4000,
		},
		Effects = function(weather)
			weather:CreateCrystalRain(200)
		end
	},

	BloodMoon = {
		Name = "Blood Moon",
		Duration = 300,
		Lighting = {
			Brightness = 0.4,
			OutdoorAmbient = Color3.fromRGB(80, 20, 20),
			Ambient = Color3.fromRGB(120, 40, 40),
			ClockTime = 0,
			FogEnd = 2000,
			FogColor = Color3.fromRGB(100, 30, 30),
		},
		Effects = function(weather)
			weather:CreateBloodMoon()
			weather:CreateRedFog()
		end
	},

	Eclipse = {
		Name = "Solar Eclipse",
		Duration = 180,
		Lighting = {
			Brightness = 0.1,
			OutdoorAmbient = Color3.fromRGB(20, 20, 40),
			Ambient = Color3.fromRGB(40, 40, 60),
			ClockTime = 12,
			FogEnd = 5000,
		},
		Effects = function(weather)
			weather:CreateEclipse()
		end
	},

	StarShower = {
		Name = "Falling Stars",
		Duration = 250,
		Lighting = {
			Brightness = 0.5,
			OutdoorAmbient = Color3.fromRGB(40, 40, 80),
			Ambient = Color3.fromRGB(80, 80, 120),
			ClockTime = 0,
			FogEnd = 10000,
		},
		Effects = function(weather)
			weather:CreateStarShower()
		end
	},

	EnchantedMist = {
		Name = "Enchanted Mist",
		Duration = 220,
		Lighting = {
			Brightness = 1,
			OutdoorAmbient = Color3.fromRGB(100, 150, 180),
			Ambient = Color3.fromRGB(150, 200, 220),
			FogEnd = 300,
			FogColor = Color3.fromRGB(180, 220, 255),
		},
		Effects = function(weather)
			weather:CreateEnchantedMist()
		end
	},

	FirestormApocalypse = {
		Name = "Firestorm",
		Duration = 200,
		Lighting = {
			Brightness = 1.5,
			OutdoorAmbient = Color3.fromRGB(150, 80, 30),
			Ambient = Color3.fromRGB(200, 100, 40),
			FogEnd = 1000,
			FogColor = Color3.fromRGB(150, 70, 30),
		},
		Effects = function(weather)
			weather:CreateFirestorm()
		end
	},

	AcidRain = {
		Name = "Acid Rain",
		Duration = 180,
		Lighting = {
			Brightness = 0.8,
			OutdoorAmbient = Color3.fromRGB(80, 120, 60),
			Ambient = Color3.fromRGB(120, 160, 100),
			FogEnd = 1500,
			FogColor = Color3.fromRGB(100, 150, 80),
		},
		Effects = function(weather)
			weather:CreateAcidRain(400)
		end
	},

	
	Sandstorm = {
		Name = "Sandstorm",
		Duration = 200,
		Lighting = {
			Brightness = 0.6,
			OutdoorAmbient = Color3.fromRGB(140, 110, 70),
			Ambient = Color3.fromRGB(180, 140, 90),
			FogEnd = 300,
			FogColor = Color3.fromRGB(200, 170, 120),
		},
		Effects = function(weather)
			weather:CreateSandstorm(600)
		end
	},

	Heatwave = {
		Name = "Heatwave",
		Duration = 240,
		Lighting = {
			Brightness = 2.5,
			OutdoorAmbient = Color3.fromRGB(180, 150, 100),
			Ambient = Color3.fromRGB(255, 220, 150),
			ClockTime = 14,
			FogEnd = 8000,
		},
		Effects = function(weather)
			weather:CreateHeatDistortion()
		end
	},

	Tornado = {
		Name = "Tornado",
		Duration = 150,
		Lighting = {
			Brightness = 0.4,
			OutdoorAmbient = Color3.fromRGB(60, 70, 60),
			Ambient = Color3.fromRGB(100, 110, 100),
			FogEnd = 800,
			FogColor = Color3.fromRGB(80, 90, 80),
		},
		Effects = function(weather)
			weather:CreateTornado()
		end
	},

	VoidStorm = {
		Name = "Void Storm",
		Duration = 200,
		Lighting = {
			Brightness = 0.1,
			OutdoorAmbient = Color3.fromRGB(10, 0, 20),
			Ambient = Color3.fromRGB(30, 10, 50),
			ClockTime = 0,
			FogEnd = 400,
			FogColor = Color3.fromRGB(20, 0, 40),
		},
		Effects = function(weather)
			weather:CreateVoidStorm()
		end
	},

	
	CherryBlossoms = {
		Name = "Cherry Blossoms",
		Duration = 300,
		Lighting = {
			Brightness = 1.8,
			OutdoorAmbient = Color3.fromRGB(180, 140, 160),
			Ambient = Color3.fromRGB(255, 200, 220),
			ClockTime = 14,
			FogEnd = 6000,
		},
		Effects = function(weather)
			weather:CreateCherryBlossoms(150)
		end
	},

	AutumnLeaves = {
		Name = "Autumn Leaves",
		Duration = 280,
		Lighting = {
			Brightness = 1.6,
			OutdoorAmbient = Color3.fromRGB(150, 100, 60),
			Ambient = Color3.fromRGB(220, 160, 100),
			ClockTime = 16,
			FogEnd = 5000,
		},
		Effects = function(weather)
			weather:CreateFallingLeaves(120)
		end
	},

	Fireflies = {
		Name = "Firefly Night",
		Duration = 300,
		Lighting = {
			Brightness = 0.4,
			OutdoorAmbient = Color3.fromRGB(40, 60, 50),
			Ambient = Color3.fromRGB(80, 100, 90),
			ClockTime = 22,
			FogEnd = 3000,
		},
		Effects = function(weather)
			weather:CreateFireflies(200)
		end
	},

	RainbowRain = {
		Name = "Rainbow Rain",
		Duration = 220,
		Lighting = {
			Brightness = 1.5,
			OutdoorAmbient = Color3.fromRGB(140, 140, 160),
			Ambient = Color3.fromRGB(200, 200, 220),
			FogEnd = 4000,
		},
		Effects = function(weather)
			weather:CreateRainbowRain(300)
			weather:CreateRainbow()
		end
	},

	FloatingLanterns = {
		Name = "Sky Lanterns",
		Duration = 260,
		Lighting = {
			Brightness = 0.6,
			OutdoorAmbient = Color3.fromRGB(80, 70, 60),
			Ambient = Color3.fromRGB(120, 110, 100),
			ClockTime = 20,
			FogEnd = 4000,
		},
		Effects = function(weather)
			weather:CreateSkyLanterns(80)
		end
	},

	
	CosmicStorm = {
		Name = "Cosmic Storm",
		Duration = 240,
		Lighting = {
			Brightness = 0.8,
			OutdoorAmbient = Color3.fromRGB(60, 40, 100),
			Ambient = Color3.fromRGB(100, 80, 160),
			ClockTime = 0,
			FogEnd = 6000,
		},
		Effects = function(weather)
			weather:CreateCosmicStorm()
		end
	},

	DimensionalRift = {
		Name = "Dimensional Rift",
		Duration = 180,
		Lighting = {
			Brightness = 1,
			OutdoorAmbient = Color3.fromRGB(100, 60, 120),
			Ambient = Color3.fromRGB(150, 100, 180),
			FogEnd = 2000,
			FogColor = Color3.fromRGB(120, 80, 150),
		},
		Effects = function(weather)
			weather:CreateDimensionalRift()
		end
	},

	TimeFracture = {
		Name = "Time Fracture",
		Duration = 200,
		Lighting = {
			Brightness = 1.2,
			OutdoorAmbient = Color3.fromRGB(80, 120, 140),
			Ambient = Color3.fromRGB(120, 180, 200),
			FogEnd = 3000,
		},
		Effects = function(weather)
			weather:CreateTimeFracture()
		end
	},

	GravityStorm = {
		Name = "Gravity Storm",
		Duration = 180,
		Lighting = {
			Brightness = 0.7,
			OutdoorAmbient = Color3.fromRGB(70, 60, 90),
			Ambient = Color3.fromRGB(110, 100, 140),
			FogEnd = 4000,
		},
		Effects = function(weather)
			weather:CreateGravityStorm()
		end
	},

	
	PollenStorm = {
		Name = "Pollen Storm",
		Duration = 220,
		Lighting = {
			Brightness = 1.7,
			OutdoorAmbient = Color3.fromRGB(160, 180, 120),
			Ambient = Color3.fromRGB(220, 240, 180),
			ClockTime = 13,
			FogEnd = 5000,
		},
		Effects = function(weather)
			weather:CreatePollenStorm(250)
		end
	},

	BioluminescentSpores = {
		Name = "Glowing Spores",
		Duration = 240,
		Lighting = {
			Brightness = 0.5,
			OutdoorAmbient = Color3.fromRGB(60, 100, 80),
			Ambient = Color3.fromRGB(100, 150, 120),
			ClockTime = 21,
			FogEnd = 2000,
		},
		Effects = function(weather)
			weather:CreateBioluminescentSpores(180)
		end
	},

	SeedRain = {
		Name = "Seed Rain",
		Duration = 200,
		Lighting = {
			Brightness = 1.4,
			OutdoorAmbient = Color3.fromRGB(120, 150, 100),
			Ambient = Color3.fromRGB(180, 220, 160),
			FogEnd = 5000,
		},
		Effects = function(weather)
			weather:CreateSeedRain(150)
		end
	},

	PrismaticButterflies = {
		Name = "Rainbow Butterflies",
		Duration = 260,
		Lighting = {
			Brightness = 1.6,
			OutdoorAmbient = Color3.fromRGB(150, 150, 170),
			Ambient = Color3.fromRGB(220, 220, 240),
			ClockTime = 15,
			FogEnd = 6000,
		},
		Effects = function(weather)
			weather:CreatePrismaticButterflies(100)
		end
	},



	LightningRain = {
		Name = "Lightning Rain",
		Duration = 180,
		Lighting = {
			Brightness = 1,
			OutdoorAmbient = Color3.fromRGB(100, 100, 140),
			Ambient = Color3.fromRGB(150, 150, 200),
			FogEnd = 2000,
		},
		Effects = function(weather)
			weather:CreateLightningRain()
		end
	},

	FrostWave = {
		Name = "Frost Wave",
		Duration = 200,
		Lighting = {
			Brightness = 1.5,
			OutdoorAmbient = Color3.fromRGB(150, 180, 200),
			Ambient = Color3.fromRGB(200, 230, 255),
			FogEnd = 3000,
			FogColor = Color3.fromRGB(210, 230, 250),
		},
		Effects = function(weather)
			weather:CreateFrostWave()
		end
	},

	EmberStorm = {
		Name = "Ember Storm",
		Duration = 190,
		Lighting = {
			Brightness = 1.2,
			OutdoorAmbient = Color3.fromRGB(140, 80, 40),
			Ambient = Color3.fromRGB(200, 120, 60),
			FogEnd = 1500,
			FogColor = Color3.fromRGB(150, 90, 50),
		},
		Effects = function(weather)
			weather:CreateEmberStorm(300)
		end
	},
}


function WeatherModule.new()
	local self = setmetatable({}, WeatherModule)

	self.currentWeather = nil
	self.activeEffects = {}
	self.originalLighting = {
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Ambient = Lighting.Ambient,
		ClockTime = Lighting.ClockTime,
		FogEnd = Lighting.FogEnd,
		FogColor = Lighting.FogColor,
	}

	return self
end


function WeatherModule:ChangeWeather(weatherName: string)
	local weatherConfig = WeatherTypes[weatherName]
	if not weatherConfig then
		warn("[WEATHER] Weather type '" .. weatherName .. "' does not exist!")
		return false
	end

	
	if self.currentWeather then
		self:ClearWeather()
	end

	self.currentWeather = weatherName

	print("[WEATHER] Changing to:", weatherConfig.Name)

	
	for property, value in pairs(weatherConfig.Lighting) do
		TweenService:Create(
			Lighting,
			TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{[property] = value}
		):Play()
	end



	if weatherConfig.Effects then
		weatherConfig.Effects(self)
	end


	WeatherChangedEvent:FireAllClients(weatherName, weatherConfig.Name, weatherConfig.Duration)

	return true
end



function WeatherModule:ClearWeather()
	print("[WEATHER] Clearing weather effects...")

	for _, effect in ipairs(self.activeEffects) do
		if typeof(effect) == "Instance" then
			effect:Destroy()
		elseif type(effect) == "function" then
			effect()
		elseif type(effect) == "table" and effect.Cleanup then
			effect:Cleanup()
		end
	end

	self.activeEffects = {}
	self.currentWeather = nil

	
	
	for property, value in pairs(self.originalLighting) do
		TweenService:Create(
			Lighting,
			TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{[property] = value}
		):Play()
	end
end


function WeatherModule:GetAllWeatherTypes()
	local weatherList = {}
	for name, config in pairs(WeatherTypes) do
		table.insert(weatherList, {
			ID = name,
			DisplayName = config.Name,
			Duration = config.Duration
		})
	end
	return weatherList
end

local WEATHER_BOUNDS = {
	Horizontal = 500,
	SkyHeight = 200,
}

local function randomFloat(minValue, maxValue)
	return minValue + (maxValue - minValue) * math.random()
end

local function randomPointInRadius(radius, y)
	local angle = math.random() * math.pi * 2
	local distance = radius * math.sqrt(math.random())
	return Vector3.new(math.cos(angle) * distance, y or 0, math.sin(angle) * distance)
end

local function createAnchorPart(name, size, position)
	local anchor = Instance.new('Part')
	anchor.Name = name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = size
	anchor.CFrame = CFrame.new(position)
	return anchor
end

local function createColorSequence(colors)
	if typeof(colors) == 'Color3' then
		return ColorSequence.new(colors)
	end

	return ColorSequence.new(colors)
end

function WeatherModule:_TrackEffect(effect)
	table.insert(self.activeEffects, effect)
	return effect
end

function WeatherModule:_CreateCleanupToken()
	local token = { Active = true }
	self:_TrackEffect(function()
		token.Active = false
	end)
	return token
end

function WeatherModule:_CreateEffectFolder(name)
	local folder = Instance.new('Folder')
	folder.Name = name
	folder.Parent = workspace
	return self:_TrackEffect(folder)
end

function WeatherModule:_CreateParticleField(config)
	local anchor = createAnchorPart(
		config.Name,
		config.Size or Vector3.new(WEATHER_BOUNDS.Horizontal, 1, WEATHER_BOUNDS.Horizontal),
		config.Position or Vector3.new(0, WEATHER_BOUNDS.SkyHeight, 0)
	)

	local emitter = Instance.new('ParticleEmitter')
	emitter.Texture = config.Texture
	emitter.Color = createColorSequence(config.Color)
	emitter.Size = config.SizeSequence or NumberSequence.new(1)
	emitter.Transparency = config.Transparency or NumberSequence.new(0)
	emitter.Lifetime = config.Lifetime or NumberRange.new(1)
	emitter.Rate = config.Rate or 10
	emitter.Speed = config.Speed or NumberRange.new(1)
	emitter.SpreadAngle = config.SpreadAngle or Vector2.new(0, 0)
	emitter.EmissionDirection = config.EmissionDirection or Enum.NormalId.Bottom
	emitter.Rotation = config.Rotation or NumberRange.new(0, 0)
	emitter.RotSpeed = config.RotSpeed or NumberRange.new(0, 0)
	emitter.LightEmission = config.LightEmission or 0
	emitter.Drag = config.Drag or 0
	emitter.Acceleration = config.Acceleration or Vector3.zero
	emitter.Parent = anchor

	anchor.Parent = workspace
	return self:_TrackEffect(anchor), emitter
end

function WeatherModule:_AttachPointLight(part, brightness, range, color)
	local light = Instance.new('PointLight')
	light.Brightness = brightness
	light.Range = range
	light.Color = color
	light.Parent = part
	return light
end

function WeatherModule:_StartColorCycle(instance, speed, saturation, value)
	local token = self:_CreateCleanupToken()
	local hue = math.random()

	task.spawn(function()
		while token.Active and instance.Parent do
			hue = (hue + speed) % 1
			instance.Color = Color3.fromHSV(hue, saturation, value)
			task.wait(0.1)
		end
	end)
end

function WeatherModule:_CreateTweenMover(part, targetPosition, duration)
	local tween = TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(targetPosition) }
	)
	tween:Play()
	return tween
end

function WeatherModule:_SpawnAnimatedOrb(folder, config)
	local part = Instance.new('Part')
	part.Shape = Enum.PartType.Ball
	part.Material = config.Material or Enum.Material.Neon
	part.Color = config.Color
	part.Size = config.Size
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.CFrame = CFrame.new(config.Position)
	part.Parent = folder

	if config.Light then
		self:_AttachPointLight(part, config.Light.Brightness, config.Light.Range, config.Light.Color or config.Color)
	end

	local token = self:_CreateCleanupToken()
	local origin = config.Position
	local phase = math.random() * math.pi * 2
	local lifetime = config.Lifetime or 20
	local startedAt = tick()

	task.spawn(function()
		while token.Active and part.Parent and (tick() - startedAt) < lifetime do
			local elapsed = tick() - startedAt
			local horizontal = Vector3.new(
				math.cos(elapsed * config.HorizontalSpeed + phase) * config.HorizontalRadius,
				0,
				math.sin(elapsed * config.HorizontalSpeed + phase) * config.HorizontalRadius
			)
			local vertical = math.sin(elapsed * config.VerticalSpeed + phase) * config.VerticalAmplitude
			part.CFrame = CFrame.new(origin + horizontal + Vector3.new(0, vertical, 0))
			task.wait(0.05)
		end

		if part.Parent then
			part:Destroy()
		end
	end)

	return part
end

function WeatherModule:CreateRain(count, speed)
	self:_CreateParticleField({
		Name = 'RainEmitter',
		Texture = 'rbxasset://textures/particles/smoke_main.dds',
		Color = Color3.fromRGB(100, 150, 200),
		SizeSequence = NumberSequence.new(0.3),
		Transparency = NumberSequence.new(0.5),
		Lifetime = NumberRange.new(3, 5),
		Rate = count,
		Speed = NumberRange.new(speed, speed + 10),
		SpreadAngle = Vector2.new(5, 5),
	})
end

function WeatherModule:CreateSnow(count, speed)
	self:_CreateParticleField({
		Name = 'SnowEmitter',
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = Color3.fromRGB(255, 255, 255),
		SizeSequence = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 0.3),
		}),
		Transparency = NumberSequence.new(0.2),
		Lifetime = NumberRange.new(8, 12),
		Rate = count,
		Speed = NumberRange.new(speed, speed + 5),
		SpreadAngle = Vector2.new(10, 10),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
end

function WeatherModule:CreateClouds(count, color)
	local folder = self:_CreateEffectFolder('Clouds')

	for index = 1, count do
		local angle = (index / count) * math.pi * 2
		local radius = randomFloat(120, 520)
		local cloud = Instance.new('Part')
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Color = color
		cloud.Size = Vector3.new(randomFloat(30, 60), randomFloat(15, 25), randomFloat(30, 60))
		cloud.Transparency = 0.7
		cloud.CFrame = CFrame.new(
			math.cos(angle) * radius,
			randomFloat(150, 250),
			math.sin(angle) * radius
		)
		cloud.Parent = folder
	end
end

function WeatherModule:CreateLightningStorm(radius, duration)
	local stormId = LightningModule.StartStorm(Vector3.zero, radius, duration)
	self:_TrackEffect(function()
		LightningModule.StopStorm(stormId)
	end)
end

function WeatherModule:CreateAurora()
	local folder = self:_CreateEffectFolder('Aurora')
	local token = self:_CreateCleanupToken()

	for index = 1, 3 do
		local band = Instance.new('Part')
		band.Anchored = true
		band.CanCollide = false
		band.Material = Enum.Material.Neon
		band.Size = Vector3.new(900, 80, 24)
		band.Transparency = 0.45
		band.CastShadow = false
		band.CFrame = CFrame.new(0, 260 + index * 28, -80 + index * 20) * CFrame.Angles(0, math.rad(30 + index * 12), 0)
		band.Parent = folder

		task.spawn(function()
			local elapsed = 0
			while token.Active and band.Parent do
				elapsed += 0.05
				local hue = (0.33 + elapsed * 0.02 + index * 0.12) % 1
				local sway = math.sin(elapsed * 1.6 + index) * 18
				band.Color = Color3.fromHSV(hue, 0.75, 1)
				band.CFrame = CFrame.new(sway, 260 + index * 28, -80 + index * 20) * CFrame.Angles(0, math.rad(30 + index * 12), 0)
				task.wait(0.05)
			end
		end)
	end
end

function WeatherModule:CreateMeteorShower(count)
	local folder = self:_CreateEffectFolder('MeteorShower')
	local token = self:_CreateCleanupToken()

	task.spawn(function()
		for _ = 1, count do
			if not token.Active then
				break
			end

			local startPosition = Vector3.new(randomFloat(-500, 500), 500, randomFloat(-500, 500))
			local travel = Vector3.new(randomFloat(-120, 120), -260, randomFloat(-120, 120))
			local meteor = Instance.new('Part')
			meteor.Shape = Enum.PartType.Ball
			meteor.Material = Enum.Material.Neon
			meteor.Color = Color3.fromRGB(255, 150, 50)
			meteor.Size = Vector3.new(4, 4, 4)
			meteor.Anchored = true
			meteor.CanCollide = false
			meteor.CFrame = CFrame.new(startPosition)
			meteor.Parent = folder

			local attachment0 = Instance.new('Attachment')
			attachment0.Parent = meteor
			local attachment1 = Instance.new('Attachment')
			attachment1.Position = Vector3.new(0, 2, 0)
			attachment1.Parent = meteor

			local trail = Instance.new('Trail')
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
			trail.Lifetime = 1
			trail.Attachment0 = attachment0
			trail.Attachment1 = attachment1
			trail.Parent = meteor

			self:_CreateTweenMover(meteor, startPosition + travel, randomFloat(1.6, 2.4))
			Debris:AddItem(meteor, 5)
			task.wait(randomFloat(0.6, 1.4))
		end
	end)
end

function WeatherModule:CreateCrystalRain(count)
	self:_CreateParticleField({
		Name = 'CrystalRainEmitter',
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = {
			ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 200)),
		},
		SizeSequence = NumberSequence.new(0.5),
		Transparency = NumberSequence.new(0.3),
		Lifetime = NumberRange.new(4, 6),
		Rate = count,
		Speed = NumberRange.new(40, 50),
		SpreadAngle = Vector2.new(5, 5),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 1,
	})
end

function WeatherModule:CreateBloodMoon()
	local sky = Instance.new('Sky')
	sky.MoonAngularSize = 30
	sky.MoonTextureId = 'rbxasset://sky/moon.jpg'
	sky.SkyboxBk = 'rbxasset://textures/sky/sky512_bk.tex'
	sky.SkyboxDn = 'rbxasset://textures/sky/sky512_dn.tex'
	sky.SkyboxFt = 'rbxasset://textures/sky/sky512_ft.tex'
	sky.SkyboxLf = 'rbxasset://textures/sky/sky512_lf.tex'
	sky.SkyboxRt = 'rbxasset://textures/sky/sky512_rt.tex'
	sky.SkyboxUp = 'rbxasset://textures/sky/sky512_up.tex'
	sky.Parent = Lighting

	local colorCorrection = Instance.new('ColorCorrectionEffect')
	colorCorrection.TintColor = Color3.fromRGB(255, 100, 100)
	colorCorrection.Parent = Lighting

	self:_TrackEffect(sky)
	self:_TrackEffect(colorCorrection)
end

function WeatherModule:CreateEclipse()
	local sky = Instance.new('Sky')
	sky.SunAngularSize = 20
	sky.MoonAngularSize = 20
	sky.Parent = Lighting

	local colorCorrection = Instance.new('ColorCorrectionEffect')
	colorCorrection.Brightness = -0.5
	colorCorrection.Parent = Lighting

	self:_TrackEffect(sky)
	self:_TrackEffect(colorCorrection)
end

function WeatherModule:CreateStarShower()
	local folder = self:_CreateEffectFolder('StarShower')
	local token = self:_CreateCleanupToken()

	task.spawn(function()
		while token.Active and self.currentWeather == 'StarShower' do
			local startPosition = Vector3.new(randomFloat(-300, 300), 400, randomFloat(-300, 300))
			local star = Instance.new('Part')
			star.Shape = Enum.PartType.Ball
			star.Material = Enum.Material.Neon
			star.Color = Color3.fromRGB(255, 255, 200)
			star.Size = Vector3.new(1, 1, 1)
			star.Anchored = true
			star.CanCollide = false
			star.CFrame = CFrame.new(startPosition)
			star.Parent = folder

			self:_AttachPointLight(star, 5, 20, star.Color)
			self:_CreateTweenMover(star, startPosition + Vector3.new(0, -260, 0), 3.5)
			Debris:AddItem(star, 8)
			task.wait(0.5)
		end
	end)
end

function WeatherModule:CreateEnchantedMist()
	self:_CreateParticleField({
		Name = 'EnchantedMistEmitter',
		Position = Vector3.new(0, 10, 0),
		Size = Vector3.new(WEATHER_BOUNDS.Horizontal, 50, WEATHER_BOUNDS.Horizontal),
		Texture = 'rbxasset://textures/particles/smoke_main.dds',
		Color = {
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 200, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 200)),
		},
		SizeSequence = NumberSequence.new(20),
		Transparency = NumberSequence.new(0.7),
		Lifetime = NumberRange.new(10, 15),
		Rate = 50,
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.5,
	})
end

function WeatherModule:CreateFirestorm()
	self:_CreateParticleField({
		Name = 'FirestormEmitter',
		Texture = 'rbxasset://textures/particles/fire_main.dds',
		Color = {
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0)),
		},
		SizeSequence = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.4),
		Lifetime = NumberRange.new(3, 5),
		Rate = 300,
		Speed = NumberRange.new(60, 70),
		SpreadAngle = Vector2.new(10, 10),
		LightEmission = 1,
	})
end

function WeatherModule:CreateAcidRain(count)
	self:_CreateParticleField({
		Name = 'AcidRainEmitter',
		Texture = 'rbxasset://textures/particles/smoke_main.dds',
		Color = Color3.fromRGB(100, 200, 50),
		SizeSequence = NumberSequence.new(0.4),
		Transparency = NumberSequence.new(0.4),
		Lifetime = NumberRange.new(3, 5),
		Rate = count,
		Speed = NumberRange.new(50, 60),
		SpreadAngle = Vector2.new(5, 5),
		LightEmission = 0.5,
	})
end

function WeatherModule:CreateSandstorm(count)
	self:_CreateParticleField({
		Name = 'SandstormEmitter',
		Position = Vector3.new(0, 50, 0),
		Size = Vector3.new(WEATHER_BOUNDS.Horizontal, 100, WEATHER_BOUNDS.Horizontal),
		Texture = 'rbxasset://textures/particles/smoke_main.dds',
		Color = Color3.fromRGB(200, 170, 120),
		SizeSequence = NumberSequence.new(5),
		Transparency = NumberSequence.new(0.6),
		Lifetime = NumberRange.new(8, 12),
		Rate = count,
		Speed = NumberRange.new(30, 40),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
	})
end

function WeatherModule:CreateTornado()
	local tornado = Instance.new('Part')
	tornado.Anchored = true
	tornado.CanCollide = false
	tornado.Material = Enum.Material.SmoothPlastic
	tornado.Color = Color3.fromRGB(100, 100, 100)
	tornado.Size = Vector3.new(30, 200, 30)
	tornado.Shape = Enum.PartType.Cylinder
	tornado.Transparency = 0.5
	tornado.CFrame = CFrame.new(randomFloat(-200, 200), 100, randomFloat(-200, 200)) * CFrame.Angles(0, 0, math.rad(90))
	tornado.Parent = workspace
	self:_TrackEffect(tornado)

	local token = self:_CreateCleanupToken()
	local origin = tornado.Position
	local rotation = 0
	task.spawn(function()
		while token.Active and tornado.Parent do
			rotation += math.rad(8)
			local sway = Vector3.new(math.cos(rotation) * 6, math.sin(rotation * 0.5) * 4, math.sin(rotation) * 6)
			tornado.CFrame = CFrame.new(origin + sway) * CFrame.Angles(0, 0, math.rad(90) + rotation)
			task.wait(0.05)
		end
	end)
end

function WeatherModule:CreateVoidStorm()
	self:_CreateParticleField({
		Name = 'VoidStormEmitter',
		Texture = 'rbxasset://textures/particles/smoke_main.dds',
		Color = Color3.fromRGB(20, 0, 40),
		SizeSequence = NumberSequence.new(8),
		Transparency = NumberSequence.new(0.5),
		Lifetime = NumberRange.new(5, 8),
		Rate = 200,
		Speed = NumberRange.new(20, 30),
		SpreadAngle = Vector2.new(180, 180),
	})
end

function WeatherModule:CreateCherryBlossoms(count)
	self:_CreateParticleField({
		Name = 'CherryBlossomsEmitter',
		Position = Vector3.new(0, 100, 0),
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = Color3.fromRGB(255, 180, 200),
		SizeSequence = NumberSequence.new(0.8),
		Transparency = NumberSequence.new(0.3),
		Lifetime = NumberRange.new(10, 15),
		Rate = count,
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(30, 30),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-50, 50),
	})
end

function WeatherModule:CreateFallingLeaves(count)
	self:_CreateParticleField({
		Name = 'FallingLeavesEmitter',
		Position = Vector3.new(0, 100, 0),
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = {
			ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 100, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 150, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 80, 40)),
		},
		SizeSequence = NumberSequence.new(1),
		Transparency = NumberSequence.new(0.2),
		Lifetime = NumberRange.new(12, 18),
		Rate = count,
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(40, 40),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
end

function WeatherModule:CreateFireflies(count)
	local folder = self:_CreateEffectFolder('Fireflies')

	for _ = 1, count do
		self:_SpawnAnimatedOrb(folder, {
			Color = Color3.fromRGB(255, 255, 150),
			Size = Vector3.new(0.3, 0.3, 0.3),
			Position = randomPointInRadius(220, randomFloat(5, 30)),
			HorizontalRadius = randomFloat(1, 5),
			HorizontalSpeed = randomFloat(0.8, 1.8),
			VerticalAmplitude = randomFloat(0.4, 1.5),
			VerticalSpeed = randomFloat(1, 2.2),
			Lifetime = 30,
			Light = {
				Brightness = 2,
				Range = 10,
			},
		})
	end
end

function WeatherModule:CreateRainbowRain(count)
	self:_CreateParticleField({
		Name = 'RainbowRainEmitter',
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = {
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 127, 0)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 0, 255)),
		},
		SizeSequence = NumberSequence.new(0.5),
		Transparency = NumberSequence.new(0.3),
		Lifetime = NumberRange.new(4, 6),
		Rate = count,
		Speed = NumberRange.new(50, 60),
		SpreadAngle = Vector2.new(5, 5),
		LightEmission = 1,
	})
end

function WeatherModule:CreateRainbow()
	local rainbow = Instance.new('Part')
	rainbow.Anchored = true
	rainbow.CanCollide = false
	rainbow.Material = Enum.Material.Neon
	rainbow.Size = Vector3.new(400, 5, 200)
	rainbow.Shape = Enum.PartType.Cylinder
	rainbow.CFrame = CFrame.new(0, 150, -200) * CFrame.Angles(0, 0, math.rad(90))
	rainbow.Transparency = 0.3
	rainbow.Parent = workspace
	self:_TrackEffect(rainbow)
	self:_StartColorCycle(rainbow, 0.01, 1, 1)
end

function WeatherModule:CreateSkyLanterns(count)
	local folder = self:_CreateEffectFolder('SkyLanterns')
	local token = self:_CreateCleanupToken()

	task.spawn(function()
		for _ = 1, count do
			if not token.Active then
				break
			end

			local startPosition = Vector3.new(randomFloat(-300, 300), 10, randomFloat(-300, 300))
			local lantern = Instance.new('Part')
			lantern.Material = Enum.Material.Neon
			lantern.Color = Color3.fromRGB(255, 200, 100)
			lantern.Size = Vector3.new(2, 3, 2)
			lantern.Anchored = true
			lantern.CanCollide = false
			lantern.CFrame = CFrame.new(startPosition)
			lantern.Parent = folder

			self:_AttachPointLight(lantern, 3, 25, lantern.Color)

			local riseOffset = Vector3.new(randomFloat(-20, 20), randomFloat(120, 180), randomFloat(-20, 20))
			self:_CreateTweenMover(lantern, startPosition + riseOffset, randomFloat(14, 20))
			Debris:AddItem(lantern, 60)
			task.wait(2)
		end
	end)
end

function WeatherModule:CreateCosmicStorm()
	self:_CreateParticleField({
		Name = 'CosmicStormEmitter',
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = {
			ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 50, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 100, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 255)),
		},
		SizeSequence = NumberSequence.new(1.5),
		Transparency = NumberSequence.new(0.3),
		Lifetime = NumberRange.new(5, 8),
		Rate = 300,
		Speed = NumberRange.new(40, 60),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
	})
end

function WeatherModule:CreateDimensionalRift()
	local rift = Instance.new('Part')
	rift.Anchored = true
	rift.CanCollide = false
	rift.Material = Enum.Material.Neon
	rift.Color = Color3.fromRGB(150, 100, 200)
	rift.Size = Vector3.new(50, 100, 5)
	rift.CFrame = CFrame.new(0, 50, 0)
	rift.Transparency = 0.3
	rift.Parent = workspace
	self:_TrackEffect(rift)

	TweenService:Create(
		rift,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.7, Size = Vector3.new(60, 110, 5) }
	):Play()
end

function WeatherModule:CreateTimeFracture()
	local blur = Instance.new('BlurEffect')
	blur.Size = 10
	blur.Parent = Lighting
	self:_TrackEffect(blur)

	TweenService:Create(
		blur,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = 20 }
	):Play()
end

function WeatherModule:CreateGravityStorm()
	local folder = self:_CreateEffectFolder('GravityStorm')

	for index = 1, 16 do
		local angle = (index / 16) * math.pi * 2
		local rock = Instance.new('Part')
		rock.Material = Enum.Material.Rock
		rock.Color = Color3.fromRGB(100, 100, 100)
		rock.Size = Vector3.new(randomFloat(2, 5), randomFloat(2, 5), randomFloat(2, 5))
		rock.Anchored = true
		rock.CanCollide = false
		rock.Parent = folder

		local token = self:_CreateCleanupToken()
		local radius = randomFloat(30, 90)
		local speed = randomFloat(0.4, 1.2)
		local baseHeight = randomFloat(10, 50)

		task.spawn(function()
			local elapsed = 0
			while token.Active and rock.Parent and self.currentWeather == 'GravityStorm' do
				elapsed += 0.05
				local orbit = angle + elapsed * speed
				rock.CFrame = CFrame.new(
					math.cos(orbit) * radius,
					baseHeight + math.sin(elapsed * 2 + angle) * 12,
					math.sin(orbit) * radius
				)
				task.wait(0.05)
			end
		end)
	end
end

function WeatherModule:CreatePollenStorm(count)
	self:_CreateParticleField({
		Name = 'PollenStormEmitter',
		Position = Vector3.new(0, 100, 0),
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = Color3.fromRGB(255, 255, 150),
		SizeSequence = NumberSequence.new(0.3),
		Transparency = NumberSequence.new(0.4),
		Lifetime = NumberRange.new(10, 15),
		Rate = count,
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.5,
	})
end

function WeatherModule:CreateBioluminescentSpores(count)
	local folder = self:_CreateEffectFolder('BioluminescentSpores')

	for _ = 1, count do
		local part = self:_SpawnAnimatedOrb(folder, {
			Color = Color3.fromHSV(math.random(), 0.8, 1),
			Size = Vector3.new(0.5, 0.5, 0.5),
			Position = randomPointInRadius(220, randomFloat(5, 40)),
			HorizontalRadius = randomFloat(2, 6),
			HorizontalSpeed = randomFloat(0.3, 1),
			VerticalAmplitude = randomFloat(0.4, 1.2),
			VerticalSpeed = randomFloat(0.8, 1.5),
			Lifetime = 30,
			Light = {
				Brightness = 3,
				Range = 15,
			},
		})

		self:_StartColorCycle(part, 0.01, 0.8, 1)
	end
end

function WeatherModule:CreateSeedRain(count)
	self:_CreateParticleField({
		Name = 'SeedRainEmitter',
		Position = Vector3.new(0, 150, 0),
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = Color3.fromRGB(139, 90, 60),
		SizeSequence = NumberSequence.new(0.6),
		Transparency = NumberSequence.new(0.2),
		Lifetime = NumberRange.new(8, 12),
		Rate = count,
		Speed = NumberRange.new(15, 20),
		SpreadAngle = Vector2.new(20, 20),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-100, 100),
	})
end

function WeatherModule:CreatePrismaticButterflies(count)
	local folder = self:_CreateEffectFolder('PrismaticButterflies')

	for _ = 1, count do
		local butterfly = self:_SpawnAnimatedOrb(folder, {
			Color = Color3.fromHSV(math.random(), 1, 1),
			Size = Vector3.new(1, 0.1, 1.5),
			Position = randomPointInRadius(220, randomFloat(5, 30)),
			HorizontalRadius = randomFloat(3, 10),
			HorizontalSpeed = randomFloat(1, 2.5),
			VerticalAmplitude = randomFloat(0.5, 2),
			VerticalSpeed = randomFloat(1.5, 3),
			Lifetime = 60,
		})

		self:_StartColorCycle(butterfly, 0.01, 1, 1)
	end
end

function WeatherModule:CreateLightningRain()
	self:CreateRain(300, 50)
	self:CreateLightningStorm(150, 180)
end

function WeatherModule:CreateFrostWave()
	self:_CreateParticleField({
		Name = 'FrostWaveEmitter',
		Position = Vector3.new(0, 150, 0),
		Texture = 'rbxasset://textures/particles/sparkles_main.dds',
		Color = Color3.fromRGB(200, 230, 255),
		SizeSequence = NumberSequence.new(0.8),
		Transparency = NumberSequence.new(0.3),
		Lifetime = NumberRange.new(5, 8),
		Rate = 400,
		Speed = NumberRange.new(30, 40),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.8,
	})
end

function WeatherModule:CreateEmberStorm(count)
	self:_CreateParticleField({
		Name = 'EmberStormEmitter',
		Position = Vector3.new(0, 150, 0),
		Texture = 'rbxasset://textures/particles/fire_main.dds',
		Color = {
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0)),
		},
		SizeSequence = NumberSequence.new(0.5),
		Transparency = NumberSequence.new(0.3),
		Lifetime = NumberRange.new(6, 10),
		Rate = count,
		Speed = NumberRange.new(20, 30),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
	})
end

function WeatherModule:CreateWind(speed)
	self:_CreateParticleField({
		Name = 'WindEmitter',
		Position = Vector3.new(0, 50, 0),
		Size = Vector3.new(WEATHER_BOUNDS.Horizontal, 100, WEATHER_BOUNDS.Horizontal),
		Texture = 'rbxasset://textures/particles/smoke_main.dds',
		Color = Color3.fromRGB(200, 200, 200),
		SizeSequence = NumberSequence.new(3),
		Transparency = NumberSequence.new(0.8),
		Lifetime = NumberRange.new(3, 5),
		Rate = 100,
		Speed = NumberRange.new(speed, speed + 10),
		SpreadAngle = Vector2.new(10, 90),
		EmissionDirection = Enum.NormalId.Right,
	})
end

function WeatherModule:CreateFogParticles()
	self:_CreateParticleField({
		Name = 'FogEmitter',
		Position = Vector3.new(0, 25, 0),
		Size = Vector3.new(WEATHER_BOUNDS.Horizontal, 50, WEATHER_BOUNDS.Horizontal),
		Texture = 'rbxasset://textures/particles/smoke_main.dds',
		Color = Color3.fromRGB(200, 200, 210),
		SizeSequence = NumberSequence.new(30),
		Transparency = NumberSequence.new(0.8),
		Lifetime = NumberRange.new(15, 20),
		Rate = 50,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
	})
end

function WeatherModule:CreateRedFog()
	self:_CreateParticleField({
		Name = 'RedFogEmitter',
		Position = Vector3.new(0, 25, 0),
		Size = Vector3.new(WEATHER_BOUNDS.Horizontal, 50, WEATHER_BOUNDS.Horizontal),
		Texture = 'rbxasset://textures/particles/smoke_main.dds',
		Color = Color3.fromRGB(150, 50, 50),
		SizeSequence = NumberSequence.new(30),
		Transparency = NumberSequence.new(0.7),
		Lifetime = NumberRange.new(15, 20),
		Rate = 60,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
	})
end

function WeatherModule:CreateHeatDistortion()
	local blur = Instance.new('BlurEffect')
	blur.Size = 5
	blur.Parent = Lighting
	self:_TrackEffect(blur)

	TweenService:Create(
		blur,
		TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = 9 }
	):Play()
end

return WeatherModule
