--!strict

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PacketBootstrap = require(ReplicatedStorage.Shared.Platform.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()
local RuntimeSettings = require(ReplicatedStorage.Shared.Platform.Settings.RuntimeSettings)

local EnvironmentDefinitions = require(ReplicatedStorage.Shared.Game.Environment.EnvironmentDefinitions)
local NatureAudio = require(script.NatureAudio)
local EnvironmentExposure = require(script.EnvironmentExposure)
local Rain = require(script.WindConstructor.RainModule)
local WindConstructor = require(script.WindConstructor)

local player = Players.LocalPlayer

local activeWeather = EnvironmentDefinitions.getWeather("Clear")
local windVelocity = Vector3.zero
local environmentExposure = EnvironmentExposure.Init()
local natureAudio = NatureAudio.Init(environmentExposure)
local rainVolume = -1
local rainVolumeTimer = 0
local environmentalAudioEnabled = RuntimeSettings.GetBoolean("Environmental Volume", true)
local windBlurInstance = Lighting:FindFirstChild("WindPressureBlur")
local windBlur: BlurEffect
if windBlurInstance and windBlurInstance:IsA("BlurEffect") then
	windBlur = windBlurInstance
else
	windBlur = Instance.new("BlurEffect")
	windBlur.Name = "WindPressureBlur"
	windBlur.Size = 0
	windBlur.Parent = Lighting
end

local function getRainVolume(weather: EnvironmentDefinitions.WeatherState): number
	if not environmentalAudioEnabled then
		return 0
	end

	local exposure = environmentExposure.GetState().rainExposure
	local outdoor = math.clamp(0.22 + exposure * 0.78, 0, 1)
	return (0.16 + weather.rainIntensity * 0.34) * outdoor
end

local function setRain(weather: EnvironmentDefinitions.WeatherState)
	local tween = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	if weather.rainIntensity > 0 then
		Rain:SetIntensityRatio(weather.rainIntensity, tween)
		Rain:SetSpeedRatio(math.clamp(weather.windSpeed / 24, 0.65, 1.8), tween)
		rainVolume = getRainVolume(weather)
		Rain:SetVolume(rainVolume, tween)
		Rain:SetDirection((Vector3.new(0, -1, 0) + weather.windDirection * weather.windPower * 0.22).Unit, tween)
		Rain:Enable(tween)
	else
		rainVolume = -1
		Rain:Disable(tween)
	end
end

local function updateRainVolume(deltaTime: number)
	if activeWeather.rainIntensity <= 0 then
		return
	end

	rainVolumeTimer += deltaTime
	if rainVolumeTimer < 0.75 then
		return
	end

	rainVolumeTimer = 0
	local nextVolume = getRainVolume(activeWeather)
	if math.abs(nextVolume - rainVolume) < 0.03 then
		return
	end

	rainVolume = nextVolume
	Rain:SetVolume(nextVolume, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
end

local function setWind(weather: EnvironmentDefinitions.WeatherState)
	windVelocity = weather.windDirection * weather.windSpeed * weather.windPower

	WindConstructor.Apply(weather)

	local pressure = math.clamp((weather.windSpeed * weather.windPower - 3) / 32, 0, 1)
	TweenService
		:Create(
			windBlur,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Size = pressure * 4.5 }
		)
		:Play()
end

local function applyWeather(weather: EnvironmentDefinitions.WeatherState)
	activeWeather = weather
	setRain(weather)
	setWind(weather)
	natureAudio.ApplyWeather(weather)
end

RuntimeSettings.Observe("Wind", function(value)
	natureAudio.SetWindEnabled(value ~= false)
end)

RuntimeSettings.Observe("Environmental Volume", function(value)
	environmentalAudioEnabled = value ~= false
	natureAudio.SetEnvironmentalAudioEnabled(environmentalAudioEnabled)
	if activeWeather then
		setRain(activeWeather)
	end
end)

WindConstructor.Start(activeWeather)
applyWeather(activeWeather)

Packets.packets.Weather.listen(function(data)
	applyWeather(data)
end)

RunService.Heartbeat:Connect(function(deltaTime)
	updateRainVolume(deltaTime)

	if activeWeather.windPower <= 0.12 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	local horizontalWind = Vector3.new(windVelocity.X, 0, windVelocity.Z)
	if horizontalWind.Magnitude <= 0.01 then
		return
	end

	local standingStill = humanoid.MoveDirection.Magnitude < 0.08
	local pressureScale = if standingStill then 0.25 else 0.12
	local push = horizontalWind * math.clamp(deltaTime * pressureScale, 0, if standingStill then 0.25 else 0.12)
	root.AssemblyLinearVelocity += Vector3.new(push.X, 0, push.Z)
end)
