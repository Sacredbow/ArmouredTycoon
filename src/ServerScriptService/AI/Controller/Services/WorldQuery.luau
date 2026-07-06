--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Core.Types)

type AIContext = Types.AIContext

local NPCFolder = workspace:WaitForChild("NPCs")
local isStudio = RunService:IsStudio()

local WorldQuery = {}

local function destroyLater(instance: Instance, lifetime: number)
	task.delay(lifetime, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

local function GetHumanoidRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function getPlayerFromRoot(root: BasePart?): Player?
	if not root then
		return nil
	end

	local character = root.Parent
	if not character or not character:IsA("Model") then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

function WorldQuery.GetRootPart(model: Model): BasePart
	local primaryPart = model.PrimaryPart
	if primaryPart then
		return primaryPart
	end

	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end

	return model:WaitForChild("HumanoidRootPart") :: BasePart
end

function WorldQuery.GetCurrentPosition(context: AIContext): Vector3
	local currentRoot = context.NPC.PrimaryPart
	if currentRoot then
		return currentRoot.Position
	end

	if context.PrimaryPart then
		return context.PrimaryPart.Position
	end

	local humanoidRootPart = context.NPC:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart.Position
	end

	return context.NPC:GetPivot().Position
end

function WorldQuery.GetGoalPosition(context: AIContext): Vector3?
	local goalValue = context.Goal
	if not goalValue then
		warn(`[NPCData] {context.Name} has no Goal value`)
		return nil
	end

	local goalName = goalValue.Value
	local target = workspace:FindFirstChild(goalName, true)
	if not target then
		warn(`[NPCData] Goal "{goalName}" not found for {context.Name}`)
		return nil
	end

	if target:IsA("BasePart") then
		return target.Position
	end

	if target:IsA("Model") then
		local targetRoot = target.PrimaryPart
		if targetRoot then
			return targetRoot.Position
		end

		local fallbackRoot = target:FindFirstChild("HumanoidRootPart")
		if fallbackRoot and fallbackRoot:IsA("BasePart") then
			return fallbackRoot.Position
		end

		warn(`[NPCData] Goal model "{goalName}" has no usable root part`)
		return nil
	end

	warn(`[NPCData] Goal "{goalName}" is not a BasePart or Model`)
	return nil
end

function WorldQuery.GetSeparationOffset(context: AIContext): Vector3
	local currentPosition: Vector3 = WorldQuery.GetCurrentPosition(context)
	local offset = Vector3.zero

	for _, instance: Instance in NPCFolder:GetChildren() do
		if not instance:IsA("Model") or instance == context.NPC then
			continue
		end

		local otherRoot = instance.PrimaryPart
		if not otherRoot then
			local fallbackRoot = instance:FindFirstChild("HumanoidRootPart")
			if fallbackRoot and fallbackRoot:IsA("BasePart") then
				otherRoot = fallbackRoot
			end
		end

		if otherRoot then
			local away: Vector3 = currentPosition - otherRoot.Position
			local distance = away.Magnitude
			if distance > 0 and distance < context.Config.SeparationRadius then
				offset += away.Unit * ((context.Config.SeparationRadius - distance) / context.Config.SeparationRadius)
			end
		end
	end

	if offset.Magnitude <= 0 then
		return Vector3.zero
	end

	return offset.Unit * math.min(offset.Magnitude * context.Config.SeparationStrength, context.Config.SeparationStrength)
end

function WorldQuery.FindObservablePlayer(context: AIContext): BasePart?
	local targets = WorldQuery.FindObservablePlayers(context, 1)
	return targets[1]
end

function WorldQuery.FindNearestPlayer(context: AIContext, maxDistance: number?): BasePart?
	local currentPosition: Vector3 = WorldQuery.GetCurrentPosition(context)
	local bestRoot: BasePart? = nil
	local bestDistance = maxDistance or math.huge

	for _, player in Players:GetPlayers() do
		local playerRoot = GetHumanoidRootPart(player)
		if playerRoot then
			local distance = (playerRoot.Position - currentPosition).Magnitude
			if distance > 0 and distance <= bestDistance then
				bestRoot = playerRoot
				bestDistance = distance
			end
		end
	end

	return bestRoot
end

function WorldQuery.GetPlayerFromRoot(root: BasePart?): Player?
	return getPlayerFromRoot(root)
end

function WorldQuery.IsPlayerIdle(root: BasePart?): boolean
	local player = getPlayerFromRoot(root)
	if not player or not player.Character then
		return false
	end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	return humanoid.MoveDirection.Magnitude <= 0.05
end

function WorldQuery.IsPlayerArmed(root: BasePart?): boolean
	local player = getPlayerFromRoot(root)
	if not player or not player.Character then
		return false
	end

	for _, child in ipairs(player.Character:GetChildren()) do
		if child:IsA("Tool") and child:FindFirstChild("ACS_Settings") then
			return true
		end
	end

	return false
end

function WorldQuery.FindObservablePlayers(context: AIContext, maxTargets: number?): { BasePart }
	local now = os.clock()
	if now - context.LastObservationTime < context.Config.ObservationCooldown then
		return {}
	end

	if now < context.IgnoreObservationUntil then
		return {}
	end

	local currentPosition: Vector3 = WorldQuery.GetCurrentPosition(context)
	local forward = context.PrimaryPart.CFrame.LookVector
	local maxDistance = context.Config.ObservationRadius
	local observableTargets: { { Root: BasePart, Distance: number } } = {}

	for _, player in Players:GetPlayers() do
		local playerRoot = GetHumanoidRootPart(player)
		if playerRoot then
			local offset = playerRoot.Position - currentPosition
			local distance = offset.Magnitude
			if distance > 0 and distance <= maxDistance then
				local direction = offset.Unit
				local dot = forward:Dot(direction)
				if dot >= context.Config.ObservationFrontDot then
					table.insert(observableTargets, {
						Root = playerRoot,
						Distance = distance,
					})
				end
			end
		end
	end

	table.sort(observableTargets, function(a, b)
		return a.Distance < b.Distance
	end)

	local limit = maxTargets or context.Config.ObservationMaxTargets
	local bestRoots: { BasePart } = {}
	for i = 1, math.min(limit, #observableTargets) do
		table.insert(bestRoots, observableTargets[i].Root)
	end

	if #bestRoots > 0 then
		context.LastObservationTime = now
	end

	return bestRoots
end

function WorldQuery.FindFrontBlockingPlayer(context: AIContext): BasePart?
	local currentPosition: Vector3 = WorldQuery.GetCurrentPosition(context)
	local forward = context.PrimaryPart.CFrame.LookVector
	local bestRoot: BasePart? = nil
	local bestDistance = context.Config.AvoidTriggerDistance

	for _, player in Players:GetPlayers() do
		local playerRoot = GetHumanoidRootPart(player)
		if playerRoot then
			local offset = playerRoot.Position - currentPosition
			local distance = offset.Magnitude
			if distance > 0 and distance <= bestDistance then
				local direction = offset.Unit
				local dot = forward:Dot(direction)
				if dot >= context.Config.AvoidFrontDot then
					bestRoot = playerRoot
					bestDistance = distance
				end
			end
		end
	end

	return bestRoot
end

local function createAvoidanceRayParams(context: AIContext): RaycastParams
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { context.NPC }
	rayParams.IgnoreWater = true
	return rayParams
end

local function getClearanceDistance(context: AIContext, direction: Vector3): number
	local origin = WorldQuery.GetCurrentPosition(context) + Vector3.new(0, context.Config.AvoidRaycastHeight, 0)
	local rayDirection = direction.Unit * context.Config.AvoidRaycastDistance
	local result = workspace:Raycast(origin, rayDirection, createAvoidanceRayParams(context))

	if result then
		return result.Distance
	end

	return context.Config.AvoidRaycastDistance
end

local function drawDebugRay(context: AIContext, origin: Vector3, direction: Vector3, distance: number, color: Color3)
	if not isStudio or not context.Config.DebugAvoidanceRays then
		return
	end

	local clampedDistance = math.max(distance, 0.05)
	local rayPart = Instance.new("Part")
	rayPart.Name = "AI_DebugRay"
	rayPart.Anchored = true
	rayPart.CanCollide = false
	rayPart.CanQuery = false
	rayPart.CanTouch = false
	rayPart.Material = Enum.Material.Neon
	rayPart.Color = color
	rayPart.Transparency = 0.2
	rayPart.Size = Vector3.new(context.Config.DebugRayThickness, context.Config.DebugRayThickness, clampedDistance)
	rayPart.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -clampedDistance * 0.5)
	rayPart.Parent = workspace
	destroyLater(rayPart, context.Config.DebugRayLifetime)
end

function WorldQuery.GetBestAvoidSide(context: AIContext, preferredSign: number): number
	local rightVector = context.PrimaryPart.CFrame.RightVector
	local rightClearance = getClearanceDistance(context, rightVector)
	local leftClearance = getClearanceDistance(context, -rightVector)
	local origin = WorldQuery.GetCurrentPosition(context) + Vector3.new(0, context.Config.AvoidRaycastHeight, 0)
	drawDebugRay(context, origin, rightVector, rightClearance, Color3.fromRGB(80, 255, 120))
	drawDebugRay(context, origin, -rightVector, leftClearance, Color3.fromRGB(255, 170, 40))
	local clearanceDelta = rightClearance - leftClearance

	if math.abs(clearanceDelta) <= context.Config.AvoidClearanceTieThreshold then
		if preferredSign >= 0 then
			return 1
		end

		return -1
	end

	if clearanceDelta > 0 then
		return 1
	end

	return -1
end

return WorldQuery
