
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LightningModule = require(script.LightningModule)
local EnvironmentSchedule = require(script.EnvironmentSchedule)
local EnvironmentShared = require(ReplicatedStorage.EnvironmentShared)
local ECS = require(ReplicatedStorage.ECS)



local EnvironmentService = {}

EnvironmentService.__index = EnvironmentService

local FULL_DAY_LENGTH = 600  
local currentTime = 6
local timeSpeed = 24 / FULL_DAY_LENGTH  

local DAWN_START = 5
local DAY_START = 6
local DUSK_START = 16
local NIGHT_START = 17
local WEATHER_LIGHTING_TWEEN_TIME = 4

local presets = {
	night = {
		Brightness = 0.85,
		OutdoorAmbient = Color3.fromRGB(92, 100, 132),
		Ambient = Color3.fromRGB(118, 126, 164),
		FogEnd = 5200,
	},
	dawn = {
		Brightness = 1,
		OutdoorAmbient = Color3.fromRGB(100, 80, 70),
		Ambient = Color3.fromRGB(150, 120, 100),
		FogEnd = 4000,
	},
	day = {
		Brightness = 1.1,
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		Ambient = Color3.fromRGB(255, 255, 255),
		FogEnd = 7000,
	},
	dusk = {
		Brightness = 1.05,
		OutdoorAmbient = Color3.fromRGB(112, 116, 136),
		Ambient = Color3.fromRGB(166, 164, 178),
		FogEnd = 5200,
	},
}

local weatherPresets = {
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



local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(a, b, t)
	return Color3.new(
		lerp(a.R, b.R, t),
		lerp(a.G, b.G, t),
		lerp(a.B, b.B, t)
	)
end

local function blend(a, b, t)
	return {
		Brightness = lerp(a.Brightness, b.Brightness, t),
		OutdoorAmbient = lerpColor(a.OutdoorAmbient, b.OutdoorAmbient, t),
		Ambient = lerpColor(a.Ambient, b.Ambient, t),
		FogEnd = lerp(a.FogEnd, b.FogEnd, t),
	}
end

local function blendWeather(base, weather, lightingWeight: number?)
	if not weather then
		return base
	end

	local target = weatherPresets[weather.kind]
	if not target then
		return base
	end

	local weight = math.clamp(lightingWeight or weather.lightingWeight or 0, 0, 1)
	return blend(base, target, weight)
end





local lightsAreOn = false

local function getOrCreateLightingEffect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end

	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

local function setLightEffects(item: Instance, enabled: boolean)
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("SurfaceLight") then
			descendant.Brightness = enabled and 1 or 0
		elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
			descendant.Enabled = enabled
		elseif descendant:IsA("Beam") then
			descendant.Enabled = enabled
		end
	end
end

function EnvironmentService:_SetStreetLights(enabled)
	if lightsAreOn == enabled then return end
	lightsAreOn = enabled

	for _, prop in ipairs(self.Props:GetChildren()) do
		if prop.Name == "StreetLights" and prop:IsA("Model") then
			local lightGroups = prop:GetChildren()
			for groupIndex, item in ipairs(lightGroups) do
				if item:IsA("Model") or item:IsA("Folder") or item:IsA("BasePart") then
					local delayTime = (groupIndex - 1) * 0.18
					setLightEffects(item, false)

					if enabled and self.BuildAssemble then
						self.BuildAssemble.Play(item, function()
							setLightEffects(item, true)
						end, {
							includeHidden = true,
							timingScale = 1.35 + (groupIndex % 3) * 0.18,
							pieceBudget = 54,
							maxPiecesPerPart = 3,
							creationBatchSize = 10,
							staggerPortion = 0.78,
							initialDelay = delayTime,
							settleFade = 0.22,
						})
					elseif enabled then
						setLightEffects(item, true)
						for _, part in ipairs(item:GetDescendants()) do
							if part:IsA("BasePart") then
								part.Transparency = 0
								part.CanCollide = true
							end
						end
					elseif self.BuildAssemble then
						self.BuildAssemble.Deassemble(item, nil, {
							includeHidden = true,
							timingScale = 0.9 + (groupIndex % 2) * 0.15,
							pieceBudget = 42,
							maxPiecesPerPart = 2,
							creationBatchSize = 10,
							staggerPortion = 0.62,
						})
					else
						for _, part in ipairs(item:GetDescendants()) do
							if part:IsA("BasePart") then
								part.Transparency = 1
								part.CanCollide = false
							end
						end
					end
				end
			end
		end
	end
end





function EnvironmentService:_UpdateLighting(hour)
	hour = hour % 24
	Lighting.ClockTime = hour

	if hour < DAWN_START then
		self:_ApplyLighting(blend(presets.night, presets.dawn, hour / DAWN_START))
		self:_SetStreetLights(true)

	elseif hour < DAY_START then
		self:_ApplyLighting(blend(presets.dawn, presets.day, (hour - DAWN_START) / (DAY_START - DAWN_START)))
		self:_SetStreetLights(false)

	elseif hour < DUSK_START then
		self:_ApplyLighting(presets.day)
		self:_SetStreetLights(false)

	elseif hour < NIGHT_START then
		self:_ApplyLighting(blend(presets.day, presets.dusk, (hour - DUSK_START) / (NIGHT_START - DUSK_START)))
		self:_SetStreetLights(true)

	else
		self:_ApplyLighting(blend(presets.dusk, presets.night, (hour - NIGHT_START) / (24 - NIGHT_START)))
		self:_SetStreetLights(true)
	end
end



function EnvironmentService:_ApplyLighting(props)
	props = blendWeather(props, self.CurrentWeather, self.WeatherLightingWeight)
	for k, v in pairs(props) do
		Lighting[k] = v
	end

	--self:_ApplyWeatherPostEffects()
end

--function EnvironmentService:_ApplyWeatherPostEffects()
--	local weather = self.CurrentWeather
--	local targetLightingWeight = math.max(weather.lightingWeight or 0, 0.001)
--	local weatherBlendAlpha = math.clamp((self.WeatherLightingWeight or weather.lightingWeight or 0) / targetLightingWeight, 0, 1)
--	local stormWeight = (if weather.kind == "Storm" then 1 elseif weather.kind == "Rain" then 0.58 else 0) * weatherBlendAlpha
--	local colorCorrection = getOrCreateLightingEffect("ColorCorrectionEffect", "WeatherColorGrade") :: ColorCorrectionEffect
--	local bloom = getOrCreateLightingEffect("BloomEffect", "WeatherBloom") :: BloomEffect
--	local atmosphere = getOrCreateLightingEffect("Atmosphere", "WeatherAtmosphere") :: Atmosphere

--	TweenService:Create(colorCorrection, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
--		Brightness = -0.012 * stormWeight,
--		Contrast = 0.13 * stormWeight,
--		Saturation = -0.15 * stormWeight,
--		TintColor = Color3.fromRGB(
--			math.floor(255 - 42 * stormWeight),
--			math.floor(255 - 28 * stormWeight),
--			255
--		),
--	}):Play()

--	TweenService:Create(bloom, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
--		Intensity = 0.24 * stormWeight,
--		Size = 18 + 22 * stormWeight,
--		Threshold = 1.65 - 0.32 * stormWeight,
--	}):Play()

--	TweenService:Create(atmosphere, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
--		Density = 0.38 * stormWeight,
--		Offset = 0.08 * stormWeight,
--		Glare = 0.18 * stormWeight,
--		Haze = 2.6 * stormWeight,
--		Color = Color3.fromRGB(178, 190, 204),
--		Decay = Color3.fromRGB(78, 92, 112),
--	}):Play()
--end

function EnvironmentService:_SetWeather(weather)
	local previousWeight = self.WeatherLightingWeight or (self.CurrentWeather and self.CurrentWeather.lightingWeight) or 0
	local targetWeight = weather.lightingWeight or 0

	self.CurrentWeather = weather
	self._weatherLightingTweenToken = (self._weatherLightingTweenToken or 0) + 1
	local tweenToken = self._weatherLightingTweenToken
	local startedAt = os.clock()

	task.spawn(function()
		while tweenToken == self._weatherLightingTweenToken do
			local alpha = math.clamp((os.clock() - startedAt) / WEATHER_LIGHTING_TWEEN_TIME, 0, 1)
			local easedAlpha = 1 - (1 - alpha) * (1 - alpha)
			self.WeatherLightingWeight = lerp(previousWeight, targetWeight, easedAlpha)

			if alpha >= 1 then
				break
			end

			task.wait(0.05)
		end

		if tweenToken == self._weatherLightingTweenToken then
			self.WeatherLightingWeight = targetWeight
		end
	end)
end




function EnvironmentService:_InitDayNight()
        ECS.createEntity({
                Name = "EnvironmentClock",
                EnvironmentClock = {
                        service = self,
                        currentTime = currentTime,
                        timeSpeed = timeSpeed,
                },
        })
end




function EnvironmentService:_InitWeather()
	self:_BroadcastWeather()
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			self:_BroadcastWeather(player)
		end)
	end)

        ECS.createEntity({
                Name = "EnvironmentWeatherTick",
                ScheduledTask = {
                        delay = 12,
			repeatEvery = 12,
			elapsed = 0,
			callback = function()
				self:_UpdateWeather()
			end,
		},
	})
end

function EnvironmentService:_BroadcastWeather(player)
	if not self.ClientSignals then
		return
	end

	if player then
		self.ClientSignals.Send(player, "Weather", self.CurrentWeather)
	else
		self.ClientSignals.SendAll("Weather", self.CurrentWeather)
	end
end

--function EnvironmentService:_Rain()
	
--	local RandomNumber = math.random(1, 1)
	
--	if RandomNumber == 1 then
--		--local Sky = self.LightingPackage.Sky:Clone()
--		--local Rain = self.LightingPackage.Rain:Clone()
		
		
--		--Sky.Parent = workspace
--		--Rain.Parent = workspace
		
		
			
--		end
		
			
--			--Sky:Destroy()
--			--Rain:Destroy()
--		end)
--	end 


--end


function EnvironmentService:_UpdateWeather()
	local hour = Lighting.ClockTime % 24
	if self.NightStormActive then
		self.NightStormActive = false
		self:_SetWeather(self.WeatherSchedule:GetCurrent())
		self:_BroadcastWeather()
	elseif self.WeatherSchedule:ShouldAdvance() then
		self:_SetWeather(self.WeatherSchedule:Next())
		self:_BroadcastWeather()
	end

	local weather = self.CurrentWeather
	if math.random() < weather.thunderChance then
		LightningModule.StartStorm(Vector3.new(50, 0, 0), 400, math.clamp(weather.duration * 0.35, 25, 90))
	end
	
end



function EnvironmentService.new(dependencies)
	local self = setmetatable({}, EnvironmentService)

	self.LightingPackage = dependencies.LightingPackage
	self.Props = dependencies.Props
	self.ClientSignals = dependencies.ClientSignals
	self.BuildAssemble = dependencies.BuildAssemble
	self.WeatherSchedule = EnvironmentSchedule.new()
	self.CurrentWeather = self.WeatherSchedule:GetCurrent()
	self.WeatherLightingWeight = self.CurrentWeather.lightingWeight or 0
	self.NightStormActive = false
	
	

	return self
end


function EnvironmentService:Init()
	self:_InitDayNight()
	self:_InitWeather()

end

return EnvironmentService
