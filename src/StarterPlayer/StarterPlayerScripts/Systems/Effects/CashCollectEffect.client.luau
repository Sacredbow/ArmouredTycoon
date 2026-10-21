--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Janitor = require(ReplicatedStorage.Packages.janitor)
local PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()

local player = Players.LocalPlayer
local janitor = Janitor.new()

local CASH_GREEN = Color3.fromRGB(52, 255, 126)
local CASH_DARK = Color3.fromRGB(13, 184, 78)
local CASH_PALE = Color3.fromRGB(174, 255, 200)
local CASH_CORE = Color3.fromRGB(96, 255, 144)
local DURATION = 0.55
local LAUNCH_SPREAD = 0.85
local TRAIL_LIFETIME = 0.5

janitor:Add(script.Destroying:Connect(function()
	janitor:Destroy()
end), "Disconnect", "Destroying")

type ProjectileData = {
	part: BasePart,
	start: Vector3,
	controlA: Vector3,
	controlB: Vector3,
	delay: number,
	spin: number,
	scale: number,
}

local function getRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function cubicBezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: number): Vector3
	local inverse = 1 - t
	return a * inverse ^ 3
		+ b * 3 * inverse ^ 2 * t
		+ c * 3 * inverse * t ^ 2
		+ d * t ^ 3
end

local function cubicBezierTangent(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: number): Vector3
	local inverse = 1 - t
	return (b - a) * 3 * inverse ^ 2
		+ (c - b) * 6 * inverse * t
		+ (d - c) * 3 * t ^ 2
	end

local function easeInOut(value: number): number
	return if value < 0.5 then 4 * value ^ 3 else 1 - ((-2 * value + 2) ^ 3) / 2
end

local function easeOutExpo(value: number): number
	return if value >= 1 then 1 else 1 - 2 ^ (-10 * value)
end

local function destroyLater(instance: Instance, lifetime: number)
	task.delay(lifetime, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

local function addTrail(part: BasePart, scale: number)
	local front = Instance.new("Attachment")
	front.Name = "CashTrailFront"
	front.Position = Vector3.new(0, 0, -0.34 * scale)
	front.Parent = part

	local back = Instance.new("Attachment")
	back.Name = "CashTrailBack"
	back.Position = Vector3.new(0, 0, 0.34 * scale)
	back.Parent = part

	local trail = Instance.new("Trail")
	trail.Name = "CashSustainTrail"
	trail.Attachment0 = front
	trail.Attachment1 = back
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CASH_PALE),
		ColorSequenceKeypoint.new(1, CASH_GREEN),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.58, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.45 * scale),
		NumberSequenceKeypoint.new(0.45, 0.7 * scale),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	trail.Lifetime = TRAIL_LIFETIME
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = part
end

local function createProjectile(origin: Vector3, index: number, scale: number): BasePart
	local projectile = Instance.new("Part")
	projectile.Name = "CashProjectile"
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.CanTouch = false
	projectile.CanQuery = false
	projectile.Material = Enum.Material.Neon
	projectile.Color = if index % 4 == 0 then CASH_CORE elseif index % 3 == 0 then CASH_DARK else CASH_GREEN
	projectile.Size = Vector3.new(0.5, 0.5, 0.5) * scale
	projectile.Shape = Enum.PartType.Ball
	projectile.CFrame = CFrame.new(origin)
	projectile.Parent = workspace

	addTrail(projectile, scale)
	return projectile
end

local function makeProjectileData(origin: Vector3, target: Vector3, amount: number): { ProjectileData }
	local count = math.clamp(math.floor(math.log10(math.max(amount, 10)) * 7), 18, 42)
	local projectiles = table.create(count)

	for index = 1, count do
		local angle = (index / count) * math.pi * 2
		local side = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local scale = 0.45 + (index % 4) * 0.08
		local scatter = 1.3 + (index % 6) * 0.46
		local start = origin + side * scatter + Vector3.new(0, 0.45 + (index % 5) * 0.2, 0)
		local arch = 5.5 + (index % 7) * 0.52
		local controlA = start + side * (4.5 + (index % 4) * 0.85) + Vector3.new(0, arch, 0)
		local controlB = target + side * (2.6 + (index % 5) * 0.28) + Vector3.new(0, arch * 0.62, 0)
		local part = createProjectile(start, index, scale)

		projectiles[index] = {
			part = part,
			start = start,
			controlA = controlA,
			controlB = controlB,
			delay = ((index - 1) / count) * LAUNCH_SPREAD,
			spin = if index % 2 == 0 then 1 else -1,
			scale = scale,
		}
		destroyLater(part, DURATION + TRAIL_LIFETIME + 0.8)
	end

	return projectiles
end

local function playCashEffect(origin: Vector3, amount: number)
	local root = getRoot()
	if not root then
		return
	end

	local startedAt = os.clock()
	local projectiles = makeProjectileData(origin, root.Position + Vector3.new(0, 1.15, 0), amount)

	local connection: RBXScriptConnection?
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startedAt
		local currentRoot = getRoot()
		if not currentRoot then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local target = currentRoot.Position + Vector3.new(0, 1.15, 0)
		for _, data in ipairs(projectiles) do
			local part = data.part
			if not part.Parent then
				continue
			end

			local raw = math.clamp((elapsed - data.delay) / DURATION, 0, 1)
			local t = easeInOut(raw)
			local projectileSurge = easeOutExpo(raw)
			local position = cubicBezier(data.start, data.controlA, data.controlB, target, t)
			local tangent = cubicBezierTangent(data.start, data.controlA, data.controlB, target, math.clamp(t, 0.02, 0.98))
			local face = if tangent.Magnitude > 0.01 then tangent.Unit else Vector3.zAxis
			part.CFrame = CFrame.lookAt(position, position + face)
				* CFrame.Angles(0, 0, (elapsed * 18 + projectileSurge * 8) * data.spin)
			part.Size = Vector3.new(0.5, 0.5, 0.5) * data.scale * (1 + math.sin(raw * math.pi) * 0.32)
			part.Transparency = math.clamp((raw - 0.94) / 0.06, 0, 1)
		end

		if elapsed >= DURATION + LAUNCH_SPREAD + 0.08 then
			if connection then
				connection:Disconnect()
			end
			for _, data in ipairs(projectiles) do
				local part = data.part
				if part.Parent then
					TweenService:Create(part, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
						Transparency = 1,
						Size = Vector3.new(0.05, 0.05, 0.05),
					}):Play()
					destroyLater(part, 0.22)
				end
			end
		end
	end)
end

janitor:Add(Packets.packets.CashCollected.listen(function(data)
	playCashEffect(data.origin, data.amount)
end), nil, "CashCollected")
