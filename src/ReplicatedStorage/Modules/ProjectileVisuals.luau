--!strict

local TweenService = game:GetService("TweenService")

local ProjectileVisuals = {}

type WeaponData = {
	TracerColor: Color3?,
	MuzzleVelocity: number?,
	BulletFlare: boolean?,
}

export type TracerOptions = {
	parent: Instance?,
	weaponData: WeaponData?,
	velocityScale: number?,
	lifetime: number?,
	distance: number?,
	width: number?,
}

local DEFAULT_TRACER_COLOR = Color3.fromRGB(255, 235, 180)
local TRACER_TEXTURE = "rbxassetid://446111271"
local FLARE_TEXTURE = "rbxassetid://1047066405"

local function destroyLater(instance: Instance, lifetime: number)
	task.delay(lifetime, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

local function safeUnit(direction: Vector3): Vector3
	if direction.Magnitude <= 0.001 then
		return Vector3.zAxis
	end

	return direction.Unit
end

function ProjectileVisuals.resolveTracerColor(weaponData: WeaponData?): Color3
	if weaponData and typeof(weaponData.TracerColor) == "Color3" then
		return weaponData.TracerColor
	end

	return DEFAULT_TRACER_COLOR
end

function ProjectileVisuals.spawnTracer(origin: Vector3, direction: Vector3, options: TracerOptions?)
	options = options or {}

	local parent = options.parent or workspace.CurrentCamera or workspace
	local weaponData = options.weaponData
	local dir = safeUnit(direction)
	local speed = math.max((weaponData and weaponData.MuzzleVelocity or 900) * (options.velocityScale or 1), 350)
	local distance = options.distance or math.clamp(speed * 0.1, 90, 360)
	local lifetime = options.lifetime or math.clamp(distance / speed, 0.055, 0.12)
	local width = options.width or 0.055
	local color = ProjectileVisuals.resolveTracerColor(weaponData)

	local folder = Instance.new("Folder")
	folder.Name = "ProjectileTracer"
	folder.Parent = parent

	local startPart = Instance.new("Part")
	startPart.Name = "TracerStart"
	startPart.Anchored = true
	startPart.CanCollide = false
	startPart.CanQuery = false
	startPart.CanTouch = false
	startPart.Transparency = 1
	startPart.Size = Vector3.one * 0.05
	startPart.CFrame = CFrame.new(origin)
	startPart.Parent = folder

	local endPart = startPart:Clone()
	endPart.Name = "TracerEnd"
	endPart.CFrame = CFrame.new(origin + dir * 2)
	endPart.Parent = folder

	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "Start"
	startAttachment.Parent = startPart

	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "End"
	endAttachment.Parent = endPart

	local beam = Instance.new("Beam")
	beam.Name = "TracerBeam"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Color = ColorSequence.new(color)
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Texture = TRACER_TEXTURE
	beam.TextureLength = 10
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.72, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Width0 = width
	beam.Width1 = width * 0.45
	beam.Parent = folder

	if weaponData and weaponData.BulletFlare == true then
		local flare = Instance.new("BillboardGui")
		flare.Name = "MuzzleFlash"
		flare.Adornee = startPart
		flare.AlwaysOnTop = false
		flare.LightInfluence = 0
		flare.Size = UDim2.fromOffset(58, 58)
		flare.Parent = folder

		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = FLARE_TEXTURE
		image.ImageColor3 = color
		image.ImageTransparency = 0.25
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = flare

		TweenService:Create(image, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageTransparency = 1,
			Size = UDim2.fromScale(0.35, 0.35),
		}):Play()
	end

	local travelTween = TweenService:Create(endPart, TweenInfo.new(lifetime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(origin + dir * distance),
	})
	local fadeTween = TweenService:Create(beam, TweenInfo.new(lifetime * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Width0 = 0,
		Width1 = 0,
	})

	travelTween:Play()
	task.delay(lifetime * 0.25, function()
		if beam.Parent then
			fadeTween:Play()
		end
	end)

	destroyLater(folder, lifetime + 0.18)
end

return ProjectileVisuals
