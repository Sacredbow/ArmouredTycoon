local TweenService = game:GetService("TweenService")
local SoundService = game:GetService('SoundService')
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage.Assets
local ECS = require(ReplicatedStorage.ECS)

local LightningModule = {}

local Config = {
	
	StrikeRadius = 120,
	StrikesPerMinute = {Min = 8, Max = 15}, 
	StrikeDelay = {Min = 0.2, Max = 1.8},


	MainBoltWidth = {Min = 2.5, Max = 5},
	BranchWidth = {Min = 1, Max = 2},
	BoltColor = Color3.fromRGB(180, 200, 255),
	GlowColor = Color3.fromRGB(220, 230, 255),

	FlashColor = Color3.fromRGB(200, 220, 255),
	FlashBrightness = 120,
	FlashRange = 250,
	FlashDuration = 0.1,
	AmbientFlashIntensity = 0.5,

	ThunderSoundId = "rbxassetid://12222030",
	ThunderVolume = 0.8,
	ThunderPitchVariation = {Min = 0.85, Max = 1.15},
	SpeedOfSound = 343,


	MaxHeight = 800, 
	MinHeight = 600,
	SegmentLength = 15,
	Jaggedness = 5, 
	BranchChance = 0.3,
	BranchAngleMax = 60,


	MaxLateralDrift = 80,  
	DriftSegments = 8,


	GrowDownSpeed = 0.4,  


	FlickerPattern = {
		{duration = 0.06, visible = true},
		{duration = 0.03, visible = false},
		{duration = 0.1, visible = true},
		{duration = 0.02, visible = false},
		{duration = 0.15, visible = true},
	}
}

local activeStorms = {}

local function destroyLater(instance, lifetime)
	task.delay(lifetime, function()
		if instance and instance.Parent then
			instance:Destroy()
		end
	end)
end

local function schedule(delay, callback, name)
	ECS.createEntity({
		Name = name or "LightningScheduledTask",
		ScheduledTask = {
			delay = delay,
			elapsed = 0,
			callback = callback,
		},
	})
end

local function scheduleRepeating(delay, repeatEvery, callback, name)
	ECS.createEntity({
		Name = name or "LightningRepeatingTask",
		ScheduledTask = {
			delay = delay,
			elapsed = 0,
			repeatEvery = repeatEvery,
			callback = callback,
		},
	})
end


local function createLightningBolt(startPos, endPos, width, parentModel)
	local totalDistance = (endPos - startPos).Magnitude
	local baseDirection = (endPos - startPos).Unit


	local driftPoints = {startPos}
	for i = 1, Config.DriftSegments do
		local progress = i / Config.DriftSegments
		local basePos = startPos:Lerp(endPos, progress)

		local driftAmount = Config.MaxLateralDrift * math.sin(progress * math.pi) 
		local randomDir = Vector3.new(
			math.random(-100, 100) / 100,
			0,
			math.random(-100, 100) / 100
		).Unit

		local driftedPos = basePos + randomDir * driftAmount
		table.insert(driftPoints, driftedPos)
	end
	table.insert(driftPoints, endPos)

	local allParts = {}

	
	for d = 1, #driftPoints - 1 do
		local segmentStart = driftPoints[d]
		local segmentEnd = driftPoints[d + 1]
		local distance = (segmentEnd - segmentStart).Magnitude
		local segments = math.ceil(distance / Config.SegmentLength)
		local direction = (segmentEnd - segmentStart).Unit

		local lastPos = segmentStart

		for i = 1, segments do
			local progress = i / segments
			local targetPos = segmentStart + (direction * distance * progress)

			
			if i < segments then
				local perpendicular1 = direction:Cross(Vector3.new(0, 1, 0)).Unit
				local perpendicular2 = direction:Cross(perpendicular1).Unit

				local jitter = Config.Jaggedness * (1 - progress * 0.3)
				targetPos = targetPos + 
					perpendicular1 * math.random(-jitter, jitter) +
					perpendicular2 * math.random(-jitter, jitter)
			else
				targetPos = segmentEnd
			end

			local segmentLength = (targetPos - lastPos).Magnitude
			local segmentCFrame = CFrame.lookAt(lastPos, targetPos) * CFrame.new(0, 0, -segmentLength / 2)

			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.Material = Enum.Material.Neon
			part.Color = Config.BoltColor
			part.Size = Vector3.new(width, width, segmentLength)
			part.CFrame = segmentCFrame
			part.CastShadow = false
			part.Transparency = 1 
			part.Parent = parentModel

			table.insert(allParts, part)

			if math.random() < Config.BranchChance and i < segments - 2 and i > 1 then
				local branchCount = math.random(1, 3)
				for b = 1, branchCount do
					local branchAngle = math.rad(math.random(-Config.BranchAngleMax, Config.BranchAngleMax))
					local branchLength = math.random(20, 50)
					local branchDir = (CFrame.Angles(branchAngle, math.random() * math.pi * 2, 0) * direction).Unit
					local branchEnd = targetPos + branchDir * branchLength

					branchEnd = branchEnd + Vector3.new(
						math.random(-8, 8),
						math.random(-15, -5),
						math.random(-8, 8)
					)

					local branchDist = (branchEnd - targetPos).Magnitude
					local branchCFrame = CFrame.lookAt(targetPos, branchEnd) * CFrame.new(0, 0, -branchDist / 2)

					local branch = Instance.new("Part")
					branch.Anchored = true
					branch.CanCollide = false
					branch.Material = Enum.Material.Neon
					branch.Color = Config.BoltColor
					branch.Size = Vector3.new(
						math.random(Config.BranchWidth.Min * 10, Config.BranchWidth.Max * 10) / 10,
						math.random(Config.BranchWidth.Min * 10, Config.BranchWidth.Max * 10) / 10,
						branchDist
					)
					branch.CFrame = branchCFrame
					branch.CastShadow = false
					branch.Transparency = 1
					branch.Parent = parentModel

					table.insert(allParts, branch)
				end
			end

			lastPos = targetPos
		end
	end

	return allParts
end


local function createImpactEffect(position, hitPart)


	local container = Instance.new("Part")
	container.Anchored = true
	container.CanCollide = false
	container.Transparency = 1
	container.Size = Vector3.new(1, 1, 1)
	container.CFrame = CFrame.new(position)
	container.Parent = workspace


	local pointLight = Instance.new("PointLight")
	pointLight.Color = Config.FlashColor
	pointLight.Brightness = Config.FlashBrightness
	pointLight.Range = Config.FlashRange
	pointLight.Shadows = true
	pointLight.Parent = container


	local glow = Instance.new("Part")
	glow.Anchored = true
	glow.CanCollide = false
	glow.Material = Enum.Material.Neon
	glow.Color = Config.GlowColor
	glow.Size = Vector3.new(12, 0.5, 12)
	glow.CFrame = CFrame.new(position) * CFrame.new(0, 0.5, 0)
	glow.Shape = Enum.PartType.Cylinder
	glow.Orientation = Vector3.new(0, 0, 90)
	glow.Transparency = 0.2
	glow.CastShadow = false
	glow.Parent = container


	local shockwave = Instance.new("Part")
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.Material = Enum.Material.Neon
	shockwave.Color = Config.BoltColor
	shockwave.Size = Vector3.new(2, 0.3, 2)
	shockwave.CFrame = CFrame.new(position) * CFrame.new(0, 0.1, 0)
	shockwave.Shape = Enum.PartType.Cylinder
	shockwave.Orientation = Vector3.new(0, 0, 90)
	shockwave.Transparency = 0.5
	shockwave.CastShadow = false
	shockwave.Parent = container


	TweenService:Create(
		shockwave,
		TweenInfo.new(0.72, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{Size = Vector3.new(68, 0.08, 68), Transparency = 1}
	):Play()

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "GroundDust"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 88, 82)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 48, 52)),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.5),
		NumberSequenceKeypoint.new(0.35, 7),
		NumberSequenceKeypoint.new(1, 12),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.65, 0.58),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(1.15, 2.4)
	dust.Speed = NumberRange.new(18, 34)
	dust.SpreadAngle = Vector2.new(180, 12)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-60, 60)
	dust.Drag = 5
	dust.Parent = container
	dust:Emit(48)


	for i = 1, 6 do
		local arc = Instance.new("Part")
		arc.Anchored = true
		arc.CanCollide = false
		arc.Material = Enum.Material.Neon
		arc.Color = Config.BoltColor
		arc.Size = Vector3.new(0.5, 0.5, math.random(8, 15))
		local angle = (i / 6) * math.pi * 2
		arc.CFrame = CFrame.new(position) * CFrame.Angles(0, angle, math.rad(math.random(-20, 20))) * CFrame.new(0, 0, -5)
		arc.CastShadow = false
		arc.Parent = container

		TweenService:Create(
			arc,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Transparency = 1}
		):Play()
	end


	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(80, 80, 100))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 8)
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	})
	smoke.Lifetime = NumberRange.new(1.5, 3)
	smoke.Rate = 80
	smoke.Speed = NumberRange.new(10, 20)
	smoke.SpreadAngle = Vector2.new(40, 40)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Parent = container
	smoke:Emit(35)


	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Config.BoltColor)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparks.Lifetime = NumberRange.new(0.3, 0.8)
	sparks.Rate = 150
	sparks.Speed = NumberRange.new(20, 40)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Drag = 3
	sparks.Parent = container
	sparks:Emit(60)

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "HotEmbers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 232, 162)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 91, 36)),
	})
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	embers.Lifetime = NumberRange.new(0.85, 1.8)
	embers.Speed = NumberRange.new(8, 26)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Acceleration = Vector3.new(0, -18, 0)
	embers.Drag = 2
	embers.LightEmission = 1
	embers.Parent = container
	embers:Emit(90)


	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 50))
	})
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4.5),
		NumberSequenceKeypoint.new(0.35, 3),
		NumberSequenceKeypoint.new(1, 0)
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	fire.Lifetime = NumberRange.new(0.65, 1.35)
	fire.Rate = 0
	fire.Speed = NumberRange.new(9, 22)
	fire.SpreadAngle = Vector2.new(45, 45)
	fire.Drag = 2
	fire.Parent = container
	fire:Emit(42)

	if hitPart and hitPart:IsA("BasePart") then
		local scorch = Assets.Lighting.Strike:Clone()
		local Effect = Assets.Lighting.Effect:Clone()
		scorch.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0)
		scorch.Parent = workspace

		Effect.CFrame = CFrame.new(position) * CFrame.new(0, 0.05, 0)
		Effect.Parent = workspace


		destroyLater(scorch, 5)
		destroyLater(Effect, 0.5)
	end

	schedule(Config.FlashDuration, function()
		local fadeTween = TweenService:Create(
			pointLight,
			TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
			{Brightness = 0, Range = 0}
		)
		local glowFade = TweenService:Create(
			glow,
			TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
			{Transparency = 1}
		)
		fadeTween:Play()
		glowFade:Play()
		destroyLater(container, 3)
	end, "Lightning:ImpactFade")

	return container
end

local function createAmbientFlash()
	local lighting = game:GetService("Lighting")
	local originalBrightness = lighting.Brightness
	local originalAmbient = lighting.Ambient

	lighting.Brightness = originalBrightness + Config.AmbientFlashIntensity
	lighting.Ambient = Config.FlashColor

	schedule(Config.FlashDuration, function()
		TweenService:Create(
			lighting,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Brightness = originalBrightness, Ambient = originalAmbient}
		):Play()
	end, "Lightning:AmbientFade")
end

local function getWeatherSoundGroup(): SoundGroup
	local soundGroup = SoundService:FindFirstChild('WeatherAudioGroup')
	if soundGroup and soundGroup:IsA('SoundGroup') then
		return soundGroup
	end

	soundGroup = Instance.new('SoundGroup')
	soundGroup.Name = 'WeatherAudioGroup'
	soundGroup.Parent = SoundService
	return soundGroup
end

local function playThunder(position)
	local sound = Instance.new("Sound")
	sound.SoundId = Config.ThunderSoundId
	sound.Volume = Config.ThunderVolume
	sound.SoundGroup = getWeatherSoundGroup()
	sound.PlaybackSpeed = math.random(Config.ThunderPitchVariation.Min * 100, Config.ThunderPitchVariation.Max * 100) / 100
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMaxDistance = 1000
	sound.RollOffMinDistance = 100

	local soundPart = Instance.new("Part")
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Transparency = 1
	soundPart.Size = Vector3.new(1, 1, 1)
	soundPart.CFrame = CFrame.new(position)
	soundPart.Parent = workspace

	sound.Parent = soundPart

	local minDistance = math.huge

	for _, player in pairs(game.Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - position).Magnitude
			minDistance = math.min(minDistance, distance)
		end
	end

	local Duration = minDistance / Config.SpeedOfSound

	schedule(Duration, function()
		sound:Play()
		destroyLater(soundPart, sound.TimeLength + 2)
	end, "Lightning:ThunderDelay")
end


local function strikeLightning(position)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		workspace:FindFirstChild("LightningBolts"),
		workspace:FindFirstChild("LightningEffects")
	}

	local startHeight = math.random(Config.MinHeight, Config.MaxHeight)
	local startPos = position + Vector3.new(
		math.random(-15, 15),  
		startHeight,
		math.random(-15, 15)
	)


	local rayResult = workspace:Raycast(startPos, Vector3.new(0, -startHeight - 100, 0), raycastParams)
	local endPos
	local hitPart

	if rayResult then
		endPos = rayResult.Position
		hitPart = rayResult.Instance
	else
		endPos = position - Vector3.new(0, startHeight, 0)
	end


	local boltModel = Instance.new("Model")
	boltModel.Name = "LightningBolt"

	local boltsFolder = workspace:FindFirstChild("LightningBolts")
	if not boltsFolder then
		boltsFolder = Instance.new("Folder")
		boltsFolder.Name = "LightningBolts"
		boltsFolder.Parent = workspace
	end
	boltModel.Parent = boltsFolder

	local boltWidth = math.random(Config.MainBoltWidth.Min * 10, Config.MainBoltWidth.Max * 10) / 10
	local boltParts = createLightningBolt(startPos, endPos, boltWidth, boltModel)


	local growSteps = 20
	local growStep = 0
	scheduleRepeating(0, Config.GrowDownSpeed / growSteps, function()
		growStep += 1
		local progress = growStep / growSteps
		for _, part in ipairs(boltParts) do
			part.Transparency = 0

			local partWorldPos = part.Position.Y
			local revealThreshold = startPos.Y - (startPos.Y - endPos.Y) * progress
			if partWorldPos > revealThreshold then
				part.Transparency = 1
			end
		end

		if growStep >= growSteps then
			for _, part in ipairs(boltParts) do
				part.Transparency = 0
			end

			return false
		end

		return true
	end, "Lightning:GrowBolt")

	createImpactEffect(endPos, hitPart)
	createAmbientFlash()
	playThunder(endPos)


	schedule(Config.GrowDownSpeed, function()
		local flickerIndex = 0

		local function runFlicker()
			flickerIndex += 1
			local flicker = Config.FlickerPattern[flickerIndex]
			if not flicker then
				local fadeDuration = 0.2
				for _, part in ipairs(boltParts) do
					TweenService:Create(
						part,
						TweenInfo.new(fadeDuration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
						{Transparency = 1}
					):Play()
				end

				destroyLater(boltModel, fadeDuration + 0.3)
				return
			end

			for _, part in ipairs(boltParts) do
				part.Transparency = flicker.visible and 0 or 1
			end

			schedule(flicker.duration, runFlicker, "Lightning:FlickerStep")
		end

		runFlicker()
	end, "Lightning:FlickerDelay")
end


function LightningModule.StartStorm(position, radius, duration)
	position = position or Vector3.new(0, 0, 0)
	radius = radius or Config.StrikeRadius
	duration = duration or 30 

	local stormId = game:GetService("HttpService"):GenerateGUID(false)
	activeStorms[stormId] = true



	local strikesPerMinute = math.random(Config.StrikesPerMinute.Min, Config.StrikesPerMinute.Max)
	local averageTimeBetweenStrikes = 60 / strikesPerMinute

	local startTime = tick()
	local strikeCount = 0

	local function runStormStrike()
		if not activeStorms[stormId] or (tick() - startTime) >= duration then
			activeStorms[stormId] = nil
			return
		end

			local angle = math.random() * math.pi * 2
			local distance = math.random(0, radius)
			local randomOffset = Vector3.new(
				math.cos(angle) * distance,
				0,
				math.sin(angle) * distance
			)

			local strikePosition = position + randomOffset
			strikeLightning(strikePosition)
			strikeCount = strikeCount + 1

			local delay = averageTimeBetweenStrikes + math.random(-2, 2)
			delay = math.max(1, delay)
			schedule(delay, runStormStrike, "Lightning:StormStrike")
	end

	runStormStrike()

	return stormId
end

function LightningModule.StopStorm(stormId)
	if activeStorms[stormId] then
		activeStorms[stormId] = nil

		return true
	end
	return false
end

function LightningModule.StopAllStorms()
	local count = 0
	for stormId, _ in pairs(activeStorms) do
		activeStorms[stormId] = nil
		count = count + 1
	end

end

return LightningModule
