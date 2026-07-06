--!strict

--[[
	Runtime

	Small wrappers around engine services used repeatedly by Main. These functions
	exist so the large ACS script can slowly move away from direct service calls
	and be easier to test or swap later.
]]

local Runtime = {}

local EFFECTS_FOLDER_NAME = "ACSFrameworkClientEffects"

function Runtime.getCurrentCamera(): Camera
	-- Workspace.CurrentCamera can be temporarily nil during spawn/camera swaps.
	-- Centralizing the guard gives clearer errors than indexing nil later.
	local currentCamera = workspace.CurrentCamera

	if not currentCamera then
		error("[ACS Runtime] workspace.CurrentCamera is not ready")
	end

	return currentCamera
end

function Runtime.getEffectsFolder(character: Model): Folder
	-- Local bullet/tracer effects live under the character so cleanup follows the
	-- character lifecycle and raycast ignore lists can include one folder.
	local existingFolder = character:FindFirstChild(EFFECTS_FOLDER_NAME)

	if existingFolder and existingFolder:IsA("Folder") then
		return existingFolder
	end

	local effectsFolder = Instance.new("Folder")
	effectsFolder.Name = EFFECTS_FOLDER_NAME
	effectsFolder.Parent = character

	return effectsFolder
end

function Runtime.randomRange(minimum: number, maximum: number, accuracy: number?): number
	-- ACS recoil/spread configs often use integer ranges with optional precision.
	local inverseAccuracy = 1 / (accuracy or 1)
	return math.random(minimum * inverseAccuracy, maximum * inverseAccuracy) / inverseAccuracy
end

function Runtime.raycast(origin: Vector3, direction: Vector3, ignoredInstances: { Instance }): RaycastResult?
	-- Shared raycast helper for weapon, bipod, and utility traces.
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = ignoredInstances
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	return workspace:Raycast(origin, direction, raycastParams)
end

return Runtime
