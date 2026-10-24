--!strict
--[[
	Client-side lightning presentation. The server sends only strike positions
	and a seed; all geometry, flashes, impacts, and thunder stay local.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PacketBootstrap = require(ReplicatedStorage.Shared.Platform.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()

local BOLT_COLOR = Color3.fromRGB(180, 200, 255)
local GLOW_COLOR = Color3.fromRGB(220, 230, 255)
local THUNDER_SOUND_ID = "rbxassetid://12222030"
local BOLT_WIDTH = 2.5
local SEGMENT_LENGTH = 24
local MAX_DRIFT = 55
local FLASH_BRIGHTNESS = 6

local effectsFolder = Workspace:FindFirstChild("LightningEffects")
if not effectsFolder or not effectsFolder:IsA("Folder") then
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "LightningEffects"
	effectsFolder.Parent = Workspace
end

local function createSegment(parent: Instance, from: Vector3, to: Vector3, width: number): BasePart
	local distance = (to - from).Magnitude
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = BOLT_COLOR
	part.Size = Vector3.new(width, width, distance)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	part.Parent = parent
	return part
end

local function createBolt(startPosition: Vector3, endPosition: Vector3, seed: number)
	local random = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "LightningBolt"
	model.Parent = effectsFolder

	local distance = (endPosition - startPosition).Magnitude
	local segments = math.max(1, math.ceil(distance / SEGMENT_LENGTH))
	local previous = startPosition
	local parts = {}

	for index = 1, segments do
		local progress = index / segments
		local target = startPosition:Lerp(endPosition, progress)
		if index < segments then
			local direction = (endPosition - startPosition).Unit
			local lateral = direction:Cross(Vector3.yAxis)
			if lateral.Magnitude < 0.01 then
				lateral = Vector3.xAxis
			else
				lateral = lateral.Unit
			end
			local offset = lateral * random:NextNumber(-MAX_DRIFT, MAX_DRIFT) * math.sin(progress * math.pi)
			target += offset
		end
		table.insert(parts, createSegment(model, previous, target, BOLT_WIDTH))
		previous = target
	end

	for _, part in parts do
		part.Transparency = 0
	end

	task.delay(0.35, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function createImpact(position: Vector3)
	local impact = Instance.new("Part")
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanTouch = false
	impact.CanQuery = false
	impact.CastShadow = false
	impact.Material = Enum.Material.Neon
	impact.Color = GLOW_COLOR
	impact.Shape = Enum.PartType.Cylinder
	impact.Size = Vector3.new(2, 0.25, 2)
	impact.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	impact.Parent = effectsFolder

	TweenService:Create(
		impact,
		TweenInfo.new(0.65, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{ Size = Vector3.new(48, 0.08, 48), Transparency = 1 }
	):Play()

	task.delay(0.7, function()
		if impact.Parent then
			impact:Destroy()
		end
	end)
end

local function flashAndThunder(position: Vector3)
	local previousBrightness = Lighting.Brightness
	Lighting.Brightness = previousBrightness + FLASH_BRIGHTNESS
	TweenService:Create(
		Lighting,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = previousBrightness }
	):Play()

	local camera = Workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - position).Magnitude else 0
	task.delay(math.min(distance / 343, 3), function()
		local soundPart = Instance.new("Part")
		soundPart.Anchored = true
		soundPart.CanCollide = false
		soundPart.CanTouch = false
		soundPart.CanQuery = false
		soundPart.Transparency = 1
		soundPart.Size = Vector3.one
		soundPart.CFrame = CFrame.new(position)
		soundPart.Parent = effectsFolder

		local sound = Instance.new("Sound")
		sound.SoundId = THUNDER_SOUND_ID
		sound.Volume = 0.8
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMinDistance = 100
		sound.RollOffMaxDistance = 1000
		sound.Parent = soundPart
		sound:Play()
		task.delay(4, function()
			if soundPart.Parent then
				soundPart:Destroy()
			end
		end)
	end)
end

local packet = Packets.packets and Packets.packets.LightningStrike
if packet then
	packet.listen(function(data)
		if not data then
			return
		end
		createBolt(data.startPosition, data.endPosition, data.seed)
		createImpact(data.endPosition)
		flashAndThunder(data.endPosition)
	end)
end
