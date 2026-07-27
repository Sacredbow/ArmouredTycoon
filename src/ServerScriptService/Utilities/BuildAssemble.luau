local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BuildAssemble = {}

export type PlayOptions = {
	includeHidden: boolean?,
	timingScale: number?,
	pieceBudget: number?,
	maxPiecesPerPart: number?,
	creationBatchSize: number?,
	staggerPortion: number?,
	initialDelay: number?,
	settleFade: number?,
}

export type DeassembleOptions = PlayOptions & {
	destroyAfter: boolean?,
}

local BASE_BUILD_DURATION = 0.7
local BASE_FADE_IN_DURATION = 0.7
local MAX_BUILD_DURATION = 3.6
local MAX_FADE_IN_DURATION = 2.2
local PART_TIME_SCALE = 0.012
local SIZE_TIME_SCALE = 0.007
local PIECE_BUDGET = 220
local MAX_PIECES_PER_PART = 4
local DEFAULT_CREATION_BATCH_SIZE = 28
local MIN_AXIS = 0.35
local SPREAD = 5.5

local FinalStateByPart: { [BasePart]: { Transparency: number, CanCollide: boolean } } = {}

local SLICE_AXES = {
	Enum.Axis.X,
	Enum.Axis.Y,
	Enum.Axis.Z,
}

local HIDDEN_NAME_PATTERNS = {
	"hitbox",
	"hit box",
	"magnitude",
	"trigger",
	"detector",
	"blocker",
	"collision",
	"collider",
	"touch",
	"zone",
}

local function isHelperPart(part: BasePart, options: PlayOptions?): boolean
	local lowerName = string.lower(part.Name)

	for _, pattern in ipairs(HIDDEN_NAME_PATTERNS) do
		if string.find(lowerName, pattern, 1, true) then
			return true
		end
	end

	if options and options.includeHidden == false and part.Transparency >= 1 and part.CanCollide == false and part.CanTouch == true then
		return true
	end

	return false
end

local function getAxisLength(size: Vector3, axis: Enum.Axis): number
	if axis == Enum.Axis.X then
		return size.X
	elseif axis == Enum.Axis.Y then
		return size.Y
	end

	return size.Z
end

local function isRenderablePart(instance: Instance, options: PlayOptions?): boolean
	return instance:IsA("BasePart")
		and instance.Name ~= "HumanoidRootPart"
		and not CollectionService:HasTag(instance, "Invisible")
		and not isHelperPart(instance, options)
		and (options == nil or options.includeHidden ~= false or instance.Transparency < 1)
end

local function getRenderableParts(item: Instance, options: PlayOptions?): { BasePart }
	local parts = {}
	local orderByPart = {}

	if isRenderablePart(item, options) then
		table.insert(parts, item :: BasePart)
		orderByPart[item :: BasePart] = 0
	end

	for order, descendant in ipairs(item:GetDescendants()) do
		if isRenderablePart(descendant, options) then
			local part = descendant :: BasePart
			table.insert(parts, part)
			orderByPart[part] = order
		end
	end

	table.sort(parts, function(left, right)
		local leftParent = left.Parent
		local rightParent = right.Parent
		if leftParent ~= rightParent then
			return (orderByPart[left] or 0) < (orderByPart[right] or 0)
		end

		return left.Position.Y < right.Position.Y
	end)

	return parts
end

local function getFinalTransparency(part: BasePart): number
	if part.Name == "Window" then
		return 0.65
	end

	if CollectionService:HasTag(part, "LowTransparency") then
		return 0.65
	end

	if part.Parent and part.Parent.Name == "" then
		return 0.2
	end

	if part.Transparency < 1 then
		return part.Transparency
	end

	return 0
end

local function getFinalCanCollide(part: BasePart): boolean
	if part.Name == "Window" then
		return false
	end

	if CollectionService:HasTag(part, "NonCollidable") then
		return false
	end

	return true
end

local function getModelSpan(parts: { BasePart }): number
	if #parts == 0 then
		return 0
	end

	local minPoint = parts[1].Position
	local maxPoint = parts[1].Position

	for _, part in ipairs(parts) do
		local halfSize = part.Size * 0.5
		local position = part.Position
		local partMin = position - halfSize
		local partMax = position + halfSize

		minPoint = Vector3.new(
			math.min(minPoint.X, partMin.X),
			math.min(minPoint.Y, partMin.Y),
			math.min(minPoint.Z, partMin.Z)
		)
		maxPoint = Vector3.new(
			math.max(maxPoint.X, partMax.X),
			math.max(maxPoint.Y, partMax.Y),
			math.max(maxPoint.Z, partMax.Z)
		)
	end

	return (maxPoint - minPoint).Magnitude
end

local function getTiming(parts: { BasePart }): (number, number)
	local span = getModelSpan(parts)
	local partCount = #parts
	local buildDuration = math.min(
		BASE_BUILD_DURATION + partCount * PART_TIME_SCALE + span * SIZE_TIME_SCALE,
		MAX_BUILD_DURATION
	)
	local fadeDuration = math.min(
		BASE_FADE_IN_DURATION + partCount * PART_TIME_SCALE * 0.45 + span * SIZE_TIME_SCALE * 0.45,
		MAX_FADE_IN_DURATION,
		buildDuration * 0.82
	)

	return buildDuration, fadeDuration
end

local function chooseAxis(size: Vector3, seed: number): Enum.Axis
	local sorted = table.clone(SLICE_AXES)
	table.sort(sorted, function(left, right)
		return getAxisLength(size, left) > getAxisLength(size, right)
	end)

	return sorted[((seed - 1) % #sorted) + 1]
end

local function getPieceSize(size: Vector3, axis: Enum.Axis, pieceCount: number): Vector3
	if axis == Enum.Axis.X then
		return Vector3.new(size.X / pieceCount, size.Y, size.Z)
	elseif axis == Enum.Axis.Y then
		return Vector3.new(size.X, size.Y / pieceCount, size.Z)
	end

	return Vector3.new(size.X, size.Y, size.Z / pieceCount)
end

local function getPieceOffset(size: Vector3, axis: Enum.Axis, index: number, pieceCount: number): Vector3
	local offset = ((index - 0.5) / pieceCount) - 0.5

	if axis == Enum.Axis.X then
		return Vector3.new(size.X * offset, 0, 0)
	elseif axis == Enum.Axis.Y then
		return Vector3.new(0, size.Y * offset, 0)
	end

	return Vector3.new(0, 0, size.Z * offset)
end

local function createPiece(source: BasePart, size: Vector3, cframe: CFrame): BasePart
	local piece = Instance.new("Part")
	piece.Name = source.Name .. "_BuildPiece"
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = source.CastShadow
	piece.Color = source.Color
	piece.Material = source.Material
	piece.Reflectance = source.Reflectance
	piece.Size = size
	piece.CFrame = cframe
	piece.Transparency = 1
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth

	return piece
end

local function getStartCFrame(target: CFrame, partIndex: number, pieceIndex: number): CFrame
	local side = if (partIndex + pieceIndex) % 2 == 0 then -1 else 1
	local lane = (partIndex + pieceIndex) % 3
	local lift = 3.5 + (pieceIndex % 3) * 0.65
	local sideSpread = SPREAD + (pieceIndex * 0.75) + ((partIndex % 4) * 0.3)
	local xOffset = if lane == 0 then 0 else side * sideSpread
	local topLift = if lane == 0 then 2.6 else 0
	local yOffset = lift + topLift
	local lateral = Vector3.new(
		xOffset,
		yOffset,
		((partIndex % 5) - 2) * 1.35
	)
	local angle = CFrame.Angles(
		math.rad((18 + pieceIndex * 3) * side),
		math.rad((38 + partIndex % 8) * side),
		math.rad(24 - pieceIndex * 9)
	)

	return target * CFrame.new(lateral) * angle
end

local function getPieceCountForPart(part: BasePart, partCount: number, options: PlayOptions?): number
	local largestAxis = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	if largestAxis < MIN_AXIS then
		return 1
	end

	local pieceBudget = if options and options.pieceBudget then options.pieceBudget else PIECE_BUDGET
	local maxPiecesPerPart = if options and options.maxPiecesPerPart then options.maxPiecesPerPart else MAX_PIECES_PER_PART
	local budgetedPieces = math.max(1, math.floor(pieceBudget / math.max(partCount, 1)))
	local desiredPieces = if largestAxis >= 10 then maxPiecesPerPart else math.min(3, maxPiecesPerPart)
	return math.clamp(math.min(desiredPieces, budgetedPieces), 1, maxPiecesPerPart)
end

local function getPartMoveScale(part: BasePart): number
	local largestAxis = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	if largestAxis >= 18 then
		return 0.58
	elseif largestAxis >= 10 then
		return 0.72
	elseif largestAxis >= 6 then
		return 0.86
	end

	return 1
end

local function hideFinalPart(part: BasePart, finalTransparency: number, finalCanCollide: boolean)
	FinalStateByPart[part] = {
		Transparency = finalTransparency,
		CanCollide = finalCanCollide,
	}
	part.Transparency = 1
	part.CanCollide = false
end

local function restoreFinalPart(part: BasePart)
	local finalState = FinalStateByPart[part]
	if not finalState then
		return
	end

	part.Transparency = finalState.Transparency
	part.CanCollide = finalState.CanCollide
	FinalStateByPart[part] = nil
end

local function destroyLater(instance: Instance, lifetime: number)
	task.delay(lifetime, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

function BuildAssemble.Play(item: Instance, onComplete: (() -> ())?, options: PlayOptions?)
	local parts = getRenderableParts(item, options)
	if #parts == 0 then
		if onComplete then
			onComplete()
		end
		return
	end

	local visualFolder = Instance.new("Folder")
	visualFolder.Name = item.Name .. "_BuildAssemble"
	visualFolder.Parent = workspace

	local partCount = #parts
	local buildDuration, fadeInDuration = getTiming(parts)
	local timingScale = math.clamp(if options and options.timingScale then options.timingScale else 1, 0.2, 5)
	buildDuration *= timingScale
	fadeInDuration *= timingScale
	local creationBatchSize = math.max(1, if options and options.creationBatchSize then options.creationBatchSize else DEFAULT_CREATION_BATCH_SIZE)
	local staggerPortion = math.clamp(if options and options.staggerPortion then options.staggerPortion else 0.48, 0.1, 0.9)
	local initialDelay = if options and options.initialDelay then options.initialDelay else 0
	local totalDuration = buildDuration + initialDelay
	local partTargets = {}
	local partPiecesRemaining = {}
	local tweensRemaining = 0
	local completed = false
	local creationDone = false

	for _, part in ipairs(parts) do
		if part.Parent then
			partTargets[part] = {
				Transparency = getFinalTransparency(part),
				CanCollide = getFinalCanCollide(part),
			}
		end
	end

	for part, target in pairs(partTargets) do
		if part.Parent then
			hideFinalPart(part, target.Transparency, target.CanCollide)
		end
	end

	local function tryFinish()
		if completed then
			return
		end
		if not creationDone or tweensRemaining > 0 then
			return
		end

		completed = true
		for _, part in ipairs(parts) do
			if part.Parent then
				restoreFinalPart(part)
			end
		end

		visualFolder:Destroy()
		if onComplete then
			onComplete()
		end
	end

	task.spawn(function()
		local createdThisFrame = 0
		local settleFade = math.clamp(if options and options.settleFade then options.settleFade else 0.16, 0.04, 0.5)

		for partIndex = 1, partCount do
			local part = parts[partIndex]
			if not part.Parent then
				continue
			end

			local partTarget = partTargets[part]
			local finalTransparency = if partTarget then partTarget.Transparency else 0
			local size = part.Size
			local pieceCount = getPieceCountForPart(part, partCount, options)
			partPiecesRemaining[part] = pieceCount

			local axis = chooseAxis(size, partIndex)
			local pieceSize = getPieceSize(size, axis, pieceCount)

			for pieceIndex = 1, pieceCount do
				local targetCFrame = part.CFrame * CFrame.new(getPieceOffset(size, axis, pieceIndex, pieceCount))
				local piece = createPiece(part, pieceSize, getStartCFrame(targetCFrame, partIndex, pieceIndex))
				piece.Parent = visualFolder

				local partDelay = ((partIndex - 1) / math.max(partCount, 1)) * (buildDuration * staggerPortion)
				local pieceDelay = (pieceIndex - 1) * (buildDuration * 0.035)
				local localDelay = partDelay + pieceDelay
				local delayTime = initialDelay + localDelay
				local moveTime = math.max((buildDuration - localDelay) * getPartMoveScale(part), 0.18 * timingScale)
				local fadeTime = math.max(math.min(fadeInDuration, moveTime), 0.12 * timingScale)
				local moveTween = TweenService:Create(
					piece,
					TweenInfo.new(moveTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delayTime),
					{
						CFrame = targetCFrame,
					}
				)
				local fadeTween = TweenService:Create(
					piece,
					TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delayTime),
					{
						Transparency = finalTransparency,
					}
				)

				tweensRemaining += 1
				moveTween.Completed:Connect(function()
					local remaining = partPiecesRemaining[part]
					if typeof(remaining) == "number" then
						remaining -= 1
						partPiecesRemaining[part] = remaining
						if remaining <= 0 and part.Parent then
							restoreFinalPart(part)
							TweenService:Create(
								piece,
								TweenInfo.new(settleFade, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
								{ Transparency = 1 }
							):Play()
						end
					end

					tweensRemaining -= 1
					tryFinish()
				end)
				moveTween:Play()
				fadeTween:Play()

				createdThisFrame += 1
				if createdThisFrame >= creationBatchSize then
					createdThisFrame = 0
					RunService.Heartbeat:Wait()
				end
			end
		end

		creationDone = true
		tryFinish()
	end)

	destroyLater(visualFolder, totalDuration + 1)
	task.delay(totalDuration + 0.35, function()
		creationDone = true
		tryFinish()
	end)
end

function BuildAssemble.Deassemble(item: Instance, onComplete: (() -> ())?, options: DeassembleOptions?)
	local parts = getRenderableParts(item, options)
	if #parts == 0 then
		if onComplete then
			onComplete()
		end
		return
	end

	local visualFolder = Instance.new("Folder")
	visualFolder.Name = item.Name .. "_BuildDeassemble"
	visualFolder.Parent = workspace

	local partCount = #parts
	local buildDuration, fadeDuration = getTiming(parts)
	local timingScale = math.clamp(if options and options.timingScale then options.timingScale else 1, 0.2, 5)
	buildDuration *= timingScale
	fadeDuration *= timingScale

	local creationBatchSize = math.max(1, if options and options.creationBatchSize then options.creationBatchSize else DEFAULT_CREATION_BATCH_SIZE)
	local staggerPortion = math.clamp(if options and options.staggerPortion then options.staggerPortion else 0.4, 0.1, 0.9)
	local tweensRemaining = 0
	local completed = false
	local creationDone = false

	local function tryFinish()
		if completed then
			return
		end
		if not creationDone or tweensRemaining > 0 then
			return
		end

		completed = true
		visualFolder:Destroy()

		if options and options.destroyAfter then
			item:Destroy()
		end

		if onComplete then
			onComplete()
		end
	end

	for _, part in parts do
		if part.Parent then
			hideFinalPart(part, getFinalTransparency(part), getFinalCanCollide(part))
		end
	end

	task.spawn(function()
		local createdThisFrame = 0

		for partIndex = 1, partCount do
			local part = parts[partIndex]
			if not part.Parent then
				continue
			end

			local size = part.Size
			local pieceCount = getPieceCountForPart(part, partCount, options)
			local axis = chooseAxis(size, partIndex)
			local pieceSize = getPieceSize(size, axis, pieceCount)

			for pieceIndex = 1, pieceCount do
				local startCFrame = part.CFrame * CFrame.new(getPieceOffset(size, axis, pieceIndex, pieceCount))
				local targetCFrame = getStartCFrame(startCFrame, partIndex, pieceIndex)
				local piece = createPiece(part, pieceSize, startCFrame)
				piece.Transparency = getFinalTransparency(part)
				piece.Parent = visualFolder

				local partDelay = ((partIndex - 1) / math.max(partCount, 1)) * (buildDuration * staggerPortion)
				local pieceDelay = (pieceIndex - 1) * (buildDuration * 0.025)
				local delayTime = partDelay + pieceDelay
				local moveTime = math.max((buildDuration - delayTime) * getPartMoveScale(part), 0.14 * timingScale)
				local fadeTime = math.max(math.min(fadeDuration, moveTime), 0.1 * timingScale)

				local moveTween = TweenService:Create(
					piece,
					TweenInfo.new(moveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delayTime),
					{
						CFrame = targetCFrame,
					}
				)
				local fadeTween = TweenService:Create(
					piece,
					TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delayTime),
					{
						Transparency = 1,
					}
				)

				tweensRemaining += 1
				moveTween.Completed:Connect(function()
					tweensRemaining -= 1
					tryFinish()
				end)

				moveTween:Play()
				fadeTween:Play()

				createdThisFrame += 1
				if createdThisFrame >= creationBatchSize then
					createdThisFrame = 0
					RunService.Heartbeat:Wait()
				end
			end
		end

		creationDone = true
		tryFinish()
	end)

	destroyLater(visualFolder, buildDuration + 1)
	task.delay(buildDuration + 0.35, function()
		creationDone = true
		tryFinish()
	end)
end

return BuildAssemble
