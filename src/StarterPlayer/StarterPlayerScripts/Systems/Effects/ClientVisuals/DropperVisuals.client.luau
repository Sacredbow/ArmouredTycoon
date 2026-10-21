--!strict
--[[
	Client-only dropper presentation. The server announces a production tick;
	this renderer creates and destroys the cosmetic part locally.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()

local function findConveyor(dropper: Instance): (BasePart?, BasePart?, Model?)
	local tycoon = dropper:FindFirstAncestorOfClass("Model")
	local mainItems = tycoon and tycoon:FindFirstChild("MainItems")
	local conveyor = mainItems and mainItems:FindFirstChild("Conveyor1")
	local movingPart = conveyor and conveyor:FindFirstChild("MovingPart")
	local collector = conveyor and conveyor:FindFirstChild("Collector")
	if not movingPart or not movingPart:IsA("BasePart") then
		return nil, nil, nil
	end

	return movingPart, if collector and collector:IsA("BasePart") then collector else nil, tycoon
end

local function renderDropper(data: any)
	if not data or not data.dropper or not data.spawnPart then
		return
	end
	if not data.dropper:IsA("Model") or not data.spawnPart:IsA("BasePart") then
		return
	end

	local movingPart, collector, tycoon = findConveyor(data.dropper)
	if not movingPart or not tycoon then
		return
	end

	local visuals = tycoon:FindFirstChild("DropperVisuals")
	if not visuals or not visuals:IsA("Folder") then
		visuals = Instance.new("Folder")
		visuals.Name = "DropperVisuals"
		visuals.Parent = tycoon
	end

	local part = Instance.new("Part")
	part.Name = "DropperVisual"
	part.Size = Vector3.new(1, 1, 1)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = data.spawnPart.CFrame
	part.Color = if data.dropper.Name == "GoldenDropper"
		then BrickColor.new("Gold").Color
		elseif data.dropper.Name == "EliteDropper"
		then BrickColor.new("Royal purple").Color
		else BrickColor.new("Lime green").Color
	part.Parent = visuals

	local targetY = movingPart.Position.Y + movingPart.Size.Y * 0.5 + part.Size.Y * 0.5
	local dropPosition = Vector3.new(data.spawnPart.Position.X, targetY, data.spawnPart.Position.Z)
	local rotation = data.spawnPart.CFrame - data.spawnPart.Position
	local direction = movingPart.CFrame.LookVector
	local travelDistance = movingPart.Size.Z * 0.5

	if collector then
		local projected = (collector.Position - dropPosition):Dot(direction)
		if projected > 0 then
			travelDistance = projected
		end
	end

	local targetPosition = dropPosition + direction * travelDistance
	local travelTime = math.max(travelDistance / 23, 0.1)
	local fallTween = TweenService:Create(
		part,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(dropPosition) * rotation }
	)
	fallTween:Play()

	fallTween.Completed:Once(function()
		if not part.Parent then
			return
		end
		TweenService:Create(
			part,
			TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
			{ CFrame = CFrame.new(targetPosition) * rotation }
		):Play()
	end)

	task.delay(0.35 + travelTime + 0.25, function()
		if part.Parent then
			part:Destroy()
		end
	end)
end

local packet = Packets.packets and Packets.packets.DropperVisual
if packet then
	packet.listen(renderDropper)
end