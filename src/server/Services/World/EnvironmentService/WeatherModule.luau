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
		if effect then
			effect:Destroy()
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



function WeatherModule:CreateRain(count, speed)
	local rain = Instance.new("Part")
	rain.Anchored = true
	rain.CanCollide = false
	rain.Transparency = 1
	rain.Size = Vector3.new(500, 1, 500)
	rain.CFrame = CFrame.new(0, 200, 0)
	rain.Name = "RainEmitter"

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(100, 150, 200))
	emitter.Size = NumberSequence.new(0.3)
	emitter.Transparency = NumberSequence.new(0.5)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(speed, speed + 10)
	emitter.SpreadAngle = Vector2.new(5, 5)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Parent = rain

	rain.Parent = workspace
	table.insert(self.activeEffects, rain)
end

function WeatherModule:CreateSnow(count, speed)
	local snow = Instance.new("Part")
	snow.Anchored = true
	snow.CanCollide = false
	snow.Transparency = 1
	snow.Size = Vector3.new(500, 1, 500)
	snow.CFrame = CFrame.new(0, 200, 0)
	snow.Name = "SnowEmitter"

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0.3)
	})
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(speed, speed + 5)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Parent = snow

	snow.Parent = workspace
	table.insert(self.activeEffects, snow)
end

function WeatherModule:CreateClouds(count, color)
	local cloudsFolder = Instance.new("Folder")
	cloudsFolder.Name = "Clouds"
	cloudsFolder.Parent = workspace

	for i = 1, count do
		local cloud = Instance.new("Part")
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Color = color
		cloud.Size = Vector3.new(math.random(30, 60), math.random(15, 25), math.random(30, 60))
		cloud.Transparency = 0.7
		cloud.CFrame = CFrame.new(
			math.random(-500, 500),
			math.random(150, 250),
			math.random(-500, 500)
		)
		cloud.Parent = cloudsFolder
	end

	table.insert(self.activeEffects, cloudsFolder)
end

function WeatherModule:CreateLightningStorm(radius, duration)
	
	local LightningModule = require(script.Parent.LightningModule)
	local stormId = LightningModule.StartStorm(Vector3.new(0, 0, 0), radius, duration)
	
end

function WeatherModule:CreateAurora()
	local aurora = Instance.new("Part")
	aurora.Anchored = true
	aurora.CanCollide = false
	aurora.Material = Enum.Material.Neon
	aurora.Size = Vector3.new(1000, 200, 50)
	aurora.Transparency = 0.5
	aurora.CFrame = CFrame.new(0, 300, 0) * CFrame.Angles(0, math.rad(45), 0)
	aurora.Name = "Aurora"
	aurora.Parent = workspace



	task.spawn(function()
		local hue = 0
		while aurora.Parent do
			hue = (hue + 0.005) % 1
			aurora.Color = Color3.fromHSV(hue, 0.8, 1)
			task.wait(0.1)
		end
	end)

	table.insert(self.activeEffects, aurora)
end

function WeatherModule:CreateMeteorShower(count)
	task.spawn(function()
		for i = 1, count do
			local meteor = Instance.new("Part")
			meteor.Shape = Enum.PartType.Ball
			meteor.Material = Enum.Material.Neon
			meteor.Color = Color3.fromRGB(255, 150, 50)
			meteor.Size = Vector3.new(4, 4, 4)
			meteor.CFrame = CFrame.new(
				math.random(-500, 500),
				500,
				math.random(-500, 500)
			)
			meteor.Parent = workspace

			
			
			local trail = Instance.new("Trail")
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 100, 0))
			trail.Lifetime = 1
			trail.Parent = meteor

			local a0 = Instance.new("Attachment", meteor)
			local a1 = Instance.new("Attachment", meteor)
			a1.Position = Vector3.new(0, 2, 0)
			trail.Attachment0 = a0
			trail.Attachment1 = a1

		
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
			bodyVelocity.Velocity = Vector3.new(math.random(-50, 50), -200, math.random(-50, 50))
			bodyVelocity.Parent = meteor

			Debris:AddItem(meteor, 5)

			task.wait(math.random(1, 3))
		end
	end)
end

function WeatherModule:CreateCrystalRain(count)
	local rain = Instance.new("Part")
	rain.Anchored = true
	rain.CanCollide = false
	rain.Transparency = 1
	rain.Size = Vector3.new(500, 1, 500)
	rain.CFrame = CFrame.new(0, 200, 0)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 200))
	})
	emitter.Size = NumberSequence.new(0.5)
	emitter.SContinueTransparency = NumberSequence.new(0.3)
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(40, 50)
	emitter.SpreadAngle = Vector2.new(5, 5)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.LightEmission = 1
	emitter.Parent = rain
	rain.Parent = workspace
	table.insert(self.activeEffects, rain)
end
function WeatherModule:CreateBloodMoon()
	local sky = Instance.new("Sky")
	sky.MoonAngularSize = 30
	sky.MoonTextureId = "rbxasset://sky/moon.jpg"
	sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
	sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
	sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
	sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
	sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
	sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
	sky.Parent = Lighting
	
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.TintColor = Color3.fromRGB(255, 100, 100)
	colorCorrection.Parent = Lighting

	table.insert(self.activeEffects, sky)
	table.insert(self.activeEffects, colorCorrection)
end
function WeatherModule:CreateEclipse()
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 20
	sky.MoonAngularSize = 20
	sky.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Brightness = -0.5
	colorCorrection.Parent = Lighting

	table.insert(self.activeEffects, sky)
	table.insert(self.activeEffects, colorCorrection)
end
function WeatherModule:CreateStarShower()
	task.spawn(function()
		while self.currentWeather == "StarShower" do
			local star = Instance.new("Part")
			star.Shape = Enum.PartType.Ball
			star.Material = Enum.Material.Neon
			star.Color = Color3.fromRGB(255, 255, 200)
			star.Size = Vector3.new(1, 1, 1)
			star.CFrame = CFrame.new(
				math.random(-300, 300),
				400,
				math.random(-300, 300)
			)
			star.Parent = workspace
			local light = Instance.new("PointLight")
			light.Brightness = 5
			light.Range = 20
			light.Color = Color3.fromRGB(255, 255, 200)
			light.Parent = star

			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
			bodyVelocity.Velocity = Vector3.new(0, -50, 0)
			bodyVelocity.Parent = star

			Debris:AddItem(star, 8)

			task.wait(0.5)
		end
	end)
end
function WeatherModule:CreateEnchantedMist()
	local mist = Instance.new("Part")
	mist.Anchored = true
	mist.CanCollide = false
	mist.Transparency = 1
	mist.Size = Vector3.new(500, 50, 500)
	mist.CFrame = CFrame.new(0, 10, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 200, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 200))
	})
	emitter.Size = NumberSequence.new(20)
	emitter.Transparency = NumberSequence.new(0.7)
	emitter.Lifetime = NumberRange.new(10, 15)
	emitter.Rate = 50
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.5
	emitter.Parent = mist

	mist.Parent = workspace
	table.insert(self.activeEffects, mist)
end
function WeatherModule:CreateFirestorm()
	local fire = Instance.new("Part")
	fire.Anchored = true
	fire.CanCollide = false
	fire.Transparency = 1
	fire.Size = Vector3.new(500, 1, 500)
	fire.CFrame = CFrame.new(0, 200, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0))
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0)
	})
	emitter.Transparency = NumberSequence.new(0.4)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = 300
	emitter.Speed = NumberRange.new(60, 70)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = 1
	emitter.Parent = fire

	fire.Parent = workspace
	table.insert(self.activeEffects, fire)
end
function WeatherModule:CreateAcidRain(count)
	local rain = Instance.new("Part")
	rain.Anchored = true
	rain.CanCollide = false
	rain.Transparency = 1
	rain.Size = Vector3.new(500, 1, 500)
	rain.CFrame = CFrame.new(0, 200, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(100, 200, 50))
	emitter.Size = NumberSequence.new(0.4)
	emitter.Transparency = NumberSequence.new(0.4)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(50, 60)
	emitter.SpreadAngle = Vector2.new(5, 5)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = 0.5
	emitter.Parent = rain

	rain.Parent = workspace
	table.insert(self.activeEffects, rain)
end
function WeatherModule:CreateSandstorm(count)
	local sand = Instance.new("Part")
	sand.Anchored = true
	sand.CanCollide = false
	sand.Transparency = 1
	sand.Size = Vector3.new(500, 100, 500)
	sand.CFrame = CFrame.new(0, 50, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 170, 120))
	emitter.Size = NumberSequence.new(5)
	emitter.Transparency = NumberSequence.new(0.6)
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(30, 40)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 2
	emitter.Parent = sand

	sand.Parent = workspace
	table.insert(self.activeEffects, sand)
end
function WeatherModule:CreateTornado()
	local tornado = Instance.new("Part")
	tornado.Anchored = true
	tornado.CanCollide = false
	tornado.Material = Enum.Material.SmoothPlastic
	tornado.Color = Color3.fromRGB(100, 100, 100)
	tornado.Size = Vector3.new(30, 200, 30)
	tornado.Shape = Enum.PartType.Cylinder
	tornado.Transparency = 0.5
	tornado.CFrame = CFrame.new(math.random(-200, 200), 100, math.random(-200, 200)) * CFrame.Angles(0, 0, math.rad(90))
	tornado.Parent = workspace

	task.spawn(function()
		while tornado.Parent do
			tornado.CFrame = tornado.CFrame * CFrame.Angles(0, 0, math.rad(5))
			task.wait(0.05)
		end
	end)

	table.insert(self.activeEffects, tornado)
end
function WeatherModule:CreateVoidStorm()
	local void = Instance.new("Part")
	void.Anchored = true
	void.CanCollide = false
	void.Transparency = 1
	void.Size = Vector3.new(500, 1, 500)
	void.CFrame = CFrame.new(0, 200, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(20, 0, 40))
	emitter.Size = NumberSequence.new(8)
	emitter.Transparency = NumberSequence.new(0.5)
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Rate = 200
	emitter.Speed = NumberRange.new(20, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = void

	void.Parent = workspace
	table.insert(self.activeEffects, void)
end
function WeatherModule:CreateCherryBlossoms(count)
	local blossoms = Instance.new("Part")
	blossoms.Anchored = true
	blossoms.CanCollide = false
	blossoms.Transparency = 1
	blossoms.Size = Vector3.new(500, 1, 500)
	blossoms.CFrame = CFrame.new(0, 100, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 180, 200))
	emitter.Size = NumberSequence.new(0.8)
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Lifetime = NumberRange.new(10, 15)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-50, 50)
	emitter.Parent = blossoms

	blossoms.Parent = workspace
	table.insert(self.activeEffects, blossoms)
end
function WeatherModule:CreateFallingLeaves(count)
	local leaves = Instance.new("Part")
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.Transparency = 1
	leaves.Size = Vector3.new(500, 1, 500)
	leaves.CFrame = CFrame.new(0, 100, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 100, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 150, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 80, 40))
	})
	emitter.Size = NumberSequence.new(1)
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.Lifetime = NumberRange.new(12, 18)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(3, 8)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Parent = leaves

	leaves.Parent = workspace
	table.insert(self.activeEffects, leaves)
end
function WeatherModule:CreateFireflies(count)
	task.spawn(function()
		while self.currentWeather == "Fireflies" do
			local firefly = Instance.new("Part")
			firefly.Shape = Enum.PartType.Ball
			firefly.Material = Enum.Material.Neon
			firefly.Color = Color3.fromRGB(255, 255, 150)
			firefly.Size = Vector3.new(0.3, 0.3, 0.3)
			firefly.CFrame = CFrame.new(
				math.random(-200, 200),
				math.random(5, 30),
				math.random(-200, 200)
			)
			firefly.Parent = workspace
			local light = Instance.new("PointLight")
			light.Brightness = 2
			light.Range = 10
			light.Color = Color3.fromRGB(255, 255, 150)
			light.Parent = firefly

			
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(1e4, 1e4, 1e4)
			bodyVelocity.Velocity = Vector3.new(math.random(-5, 5), math.random(-2, 2), math.random(-5, 5))
			bodyVelocity.Parent = firefly

			Debris:AddItem(firefly, 30)

			task.wait(0.3)
		end
	end)
end
function WeatherModule:CreateRainbowRain(count)
	local rain = Instance.new("Part")
	rain.Anchored = true
	rain.CanCollide = false
	rain.Transparency = 1
	rain.Size = Vector3.new(500, 1, 500)
	rain.CFrame = CFrame.new(0, 200, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 127, 0)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 0)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 0, 255))
	})
	emitter.Size = NumberSequence.new(0.5)
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(50, 60)
	emitter.SpreadAngle = Vector2.new(5, 5)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LightEmission = 1
	emitter.Parent = rain

	rain.Parent = workspace
	table.insert(self.activeEffects, rain)
end
function WeatherModule:CreateRainbow()
	local rainbow = Instance.new("Part")
	rainbow.Anchored = true
	rainbow.CanCollide = false
	rainbow.Material = Enum.Material.Neon
	rainbow.Size = Vector3.new(400, 5, 200)
	rainbow.Shape = Enum.PartType.Cylinder
	rainbow.CFrame = CFrame.new(0, 150, -200) * CFrame.Angles(0, 0, math.rad(90))
	rainbow.Transparency = 0.3
	rainbow.Parent = workspace

	task.spawn(function()
		local hue = 0
		while rainbow.Parent do
			hue = (hue + 0.01) % 1
			rainbow.Color = Color3.fromHSV(hue, 1, 1)
			task.wait(0.1)
		end
	end)

	table.insert(self.activeEffects, rainbow)
end
function WeatherModule:CreateSkyLanterns(count)
	task.spawn(function()
		for i = 1, count do
			local lantern = Instance.new("Part")
			lantern.Material = Enum.Material.Neon
			lantern.Color = Color3.fromRGB(255, 200, 100)
			lantern.Size = Vector3.new(2, 3, 2)
			lantern.CFrame = CFrame.new(
				math.random(-300, 300),
				10,
				math.random(-300, 300)
			)
			lantern.Parent = workspace
			local light = Instance.new("PointLight")
			light.Brightness = 3
			light.Range = 25
			light.Color = Color3.fromRGB(255, 200, 100)
			light.Parent = lantern

			
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
			bodyVelocity.Velocity = Vector3.new(math.random(-2, 2), 8, math.random(-2, 2))
			bodyVelocity.Parent = lantern

			Debris:AddItem(lantern, 60)

			task.wait(2)
		end
	end)
end
function WeatherModule:CreateCosmicStorm()
	local cosmic = Instance.new("Part")
	cosmic.Anchored = true
	cosmic.CanCollide = false
	cosmic.Transparency = 1
	cosmic.Size = Vector3.new(500, 1, 500)
	cosmic.CFrame = CFrame.new(0, 200, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 50, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 100, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 255))
	})
	emitter.Size = NumberSequence.new(1.5)
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Rate = 300
	emitter.Speed = NumberRange.new(40, 60)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Parent = cosmic

	cosmic.Parent = workspace
	table.insert(self.activeEffects, cosmic)
end
function WeatherModule:CreateDimensionalRift()
	local rift = Instance.new("Part")
	rift.Anchored = true
	rift.CanCollide = false
	rift.Material = Enum.Material.Neon
	rift.Color = Color3.fromRGB(150, 100, 200)
	rift.Size = Vector3.new(50, 100, 5)
	rift.CFrame = CFrame.new(0, 50, 0)
	rift.Transparency = 0.3
	rift.Parent = workspace
	
	task.spawn(function()
		while rift.Parent do
			TweenService:Create(
				rift,
				TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Transparency = 0.7, Size = Vector3.new(60, 110, 5)}
			):Play()
			task.wait(2)
		end
	end)

	table.insert(self.activeEffects, rift)
end
function WeatherModule:CreateTimeFracture()
	
	local blur = Instance.new("BlurEffect")
	blur.Size = 10
	blur.Parent = Lighting
	TweenService:Create(
		blur,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Size = 20}
	):Play()

	table.insert(self.activeEffects, blur)
end
function WeatherModule:CreateGravityStorm()
	
	task.spawn(function()
		while self.currentWeather == "GravityStorm" do
			local debris = Instance.new("Part")
			debris.Material = Enum.Material.Rock
			debris.Color = Color3.fromRGB(100, 100, 100)
			debris.Size = Vector3.new(math.random(2, 5), math.random(2, 5), math.random(2, 5))
			debris.CFrame = CFrame.new(
				math.random(-200, 200),
				10,
				math.random(-200, 200)
			)
			debris.Parent = workspace
			
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
			bodyVelocity.Velocity = Vector3.new(0, math.random(-10, 10), 0)
			bodyVelocity.Parent = debris

			Debris:AddItem(debris, 20)

			task.wait(1)
		end
	end)
end
function WeatherModule:CreatePollenStorm(count)
	local pollen = Instance.new("Part")
	pollen.Anchored = true
	pollen.CanCollide = false
	pollen.Transparency = 1
	pollen.Size = Vector3.new(500, 1, 500)
	pollen.CFrame = CFrame.new(0, 100, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 150))
	emitter.Size = NumberSequence.new(0.3)
	emitter.Transparency = NumberSequence.new(0.4)
	emitter.Lifetime = NumberRange.new(10, 15)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.5
	emitter.Parent = pollen

	pollen.Parent = workspace
	table.insert(self.activeEffects, pollen)
end
function WeatherModule:CreateBioluminescentSpores(count)
	task.spawn(function()
		while self.currentWeather == "BioluminescentSpores" do
			local spore = Instance.new("Part")
			spore.Shape = Enum.PartType.Ball
			spore.Material = Enum.Material.Neon
			spore.Color = Color3.fromHSV(math.random(), 0.8, 1)
			spore.Size = Vector3.new(0.5, 0.5, 0.5)
			spore.CFrame = CFrame.new(
				math.random(-200, 200),
				math.random(5, 40),
				math.random(-200, 200)
			)
			spore.Parent = workspace
			local light = Instance.new("PointLight")
			light.Brightness = 3
			light.Range = 15
			light.Color = spore.Color
			light.Parent = spore

			
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(1e4, 1e4, 1e4)
			bodyVelocity.Velocity = Vector3.new(math.random(-3, 3), math.random(-1, 2), math.random(-3, 3))
			bodyVelocity.Parent = spore

			Debris:AddItem(spore, 30)

			task.wait(0.5)
		end
	end)
end
function WeatherModule:CreateSeedRain(count)
	local seeds = Instance.new("Part")
	seeds.Anchored = true
	seeds.CanCollide = false
	seeds.Transparency = 1
	seeds.Size = Vector3.new(500, 1, 500)
	seeds.CFrame = CFrame.new(0, 150, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(139, 90, 60))
	emitter.Size = NumberSequence.new(0.6)
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(15, 20)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-100, 100)
	emitter.Parent = seeds

	seeds.Parent = workspace
	table.insert(self.activeEffects, seeds)
end
function WeatherModule:CreatePrismaticButterflies(count)
	task.spawn(function()
		for i = 1, count do
			local butterfly = Instance.new("Part")
			butterfly.Material = Enum.Material.Neon
			butterfly.Color = Color3.fromHSV(math.random(), 1, 1)
			butterfly.Size = Vector3.new(1, 0.1, 1.5)
			butterfly.CFrame = CFrame.new(
				math.random(-200, 200),
				math.random(5, 30),
				math.random(-200, 200)
			)
			butterfly.Parent = workspace
		
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.new(1e4, 1e4, 1e4)
			bodyVelocity.Velocity = Vector3.new(math.random(-8, 8), math.random(-3, 3), math.random(-8, 8))
			bodyVelocity.Parent = butterfly

			task.spawn(function()
				local hue = math.random()
				while butterfly.Parent do
					hue = (hue + 0.01) % 1
					butterfly.Color = Color3.fromHSV(hue, 1, 1)
					task.wait(0.1)
				end
			end)

			Debris:AddItem(butterfly, 60)

			task.wait(0.5)
		end
	end)
end
function WeatherModule:CreateLightningRain()
	self:CreateRain(300, 50)
	self:CreateLightningStorm(150, 180)
end
function WeatherModule:CreateFrostWave()
	local frost = Instance.new("Part")
	frost.Anchored = true
	frost.CanCollide = false
	frost.Transparency = 1
	frost.Size = Vector3.new(500, 1, 500)
	frost.CFrame = CFrame.new(0, 150, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	emitter.Size = NumberSequence.new(0.8)
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Rate = 400
	emitter.Speed = NumberRange.new(30, 40)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.8
	emitter.Parent = frost

	frost.Parent = workspace
	table.insert(self.activeEffects, frost)
end
function WeatherModule:CreateEmberStorm(count)
	local embers = Instance.new("Part")
	embers.Anchored = true
	embers.CanCollide = false
	embers.SContinueTransparency = 1
	embers.Size = Vector3.new(500, 1, 500)
	embers.CFrame = CFrame.new(0, 150, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0))
	})
	emitter.Size = NumberSequence.new(0.5)
	emitter.Transparency = NumberSequence.new(0.3)
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Rate = count
	emitter.Speed = NumberRange.new(20, 30)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Parent = embers

	embers.Parent = workspace
	table.insert(self.activeEffects, embers)
end
function WeatherModule:CreateWind(speed)
	
	local wind = Instance.new("Part")
	wind.Anchored = true
	wind.CanCollide = false
	wind.Transparency = 1
	wind.Size = Vector3.new(500, 100, 500)
	wind.CFrame = CFrame.new(0, 50, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	emitter.Size = NumberSequence.new(3)
	emitter.Transparency = NumberSequence.new(0.8)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = 100
	emitter.Speed = NumberRange.new(speed, speed + 10)
	emitter.SpreadAngle = Vector2.new(10, 90)
	emitter.EmissionDirection = Enum.NormalId.Right
	emitter.Parent = wind

	wind.Parent = workspace
	table.insert(self.activeEffects, wind)
end
function WeatherModule:CreateFogParticles()
	local fog = Instance.new("Part")
	fog.Anchored = true
	fog.CanCollide = false
	fog.Transparency = 1
	fog.Size = Vector3.new(500, 50, 500)
	fog.CFrame = CFrame.new(0, 25, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 210))
	emitter.Size = NumberSequence.new(30)
	emitter.Transparency = NumberSequence.new(0.8)
	emitter.Lifetime = NumberRange.new(15, 20)
	emitter.Rate = 50
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = fog

	fog.Parent = workspace
	table.insert(self.activeEffects, fog)
end
function WeatherModule:CreateRedFog()
	local fog = Instance.new("Part")
	fog.Anchored = true
	fog.CanCollide = false
	fog.Transparency = 1
	fog.Size = Vector3.new(500, 50, 500)
	fog.CFrame = CFrame.new(0, 25, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 50, 50))
	emitter.Size = NumberSequence.new(30)
	emitter.Transparency = NumberSequence.new(0.7)
	emitter.Lifetime = NumberRange.new(15, 20)
	emitter.Rate = 60
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = fog

	fog.Parent = workspace
	table.insert(self.activeEffects, fog)
end
function WeatherModule:CreateHeatDistortion()
	local blur = Instance.new("BlurEffect")
	blur.Size = 5
	blur.Parent = Lighting
	table.insert(self.activeEffects, blur)
end
return WeatherModule