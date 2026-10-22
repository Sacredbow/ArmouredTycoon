--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ROOF_SAMPLE_OFFSETS = {
	Vector3.zero,
	Vector3.new(5, 0, 0),
	Vector3.new(-5, 0, 0),
	Vector3.new(0, 0, 5),
	Vector3.new(0, 0, -5),
	Vector3.new(3.5, 0, 3.5),
	Vector3.new(-3.5, 0, 3.5),
	Vector3.new(3.5, 0, -3.5),
	Vector3.new(-3.5, 0, -3.5),
}

local WALL_DIRECTIONS = {
	Vector3.new(1, 0.15, 0),
	Vector3.new(-1, 0.15, 0),
	Vector3.new(0, 0.15, 1),
	Vector3.new(0, 0.15, -1),
	Vector3.new(0.7, 0.15, 0.7).Unit,
	Vector3.new(-0.7, 0.15, 0.7).Unit,
	Vector3.new(0.7, 0.15, -0.7).Unit,
	Vector3.new(-0.7, 0.15, -0.7).Unit,
}

export type State = {
	exposure: number,
	roofCover: number,
	wallOpen: number,
	rainExposure: number,
	indoor: boolean,
}

type EnvironmentExposureState = {
	_lastSampleAt: number,
	_sampleInterval: number,
	_state: State,
	_raycastParams: RaycastParams,
}

local EnvironmentExposure = {}
EnvironmentExposure.__index = EnvironmentExposure

local function getListenerPosition(): (Vector3?, Model?)
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if camera then
		return camera.CFrame.Position, character
	end

	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position, character
	end

	return nil, character
end

local function sample(state: EnvironmentExposureState): State
	local position, character = getListenerPosition()
	if not position then
		return state._state
	end

	local params = state._raycastParams
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if character then { character } else {}
	params.IgnoreWater = true

	local roofHits = 0
	for _, offset in ROOF_SAMPLE_OFFSETS do
		if Workspace:Raycast(position + offset, Vector3.new(0, 180, 0), params) then
			roofHits += 1
		end
	end

	local openWalls = 0
	for _, direction in WALL_DIRECTIONS do
		if not Workspace:Raycast(position, direction * 75, params) then
			openWalls += 1
		end
	end

	local roofCover = roofHits / #ROOF_SAMPLE_OFFSETS
	local wallOpen = openWalls / #WALL_DIRECTIONS
	local exposure = math.clamp((1 - roofCover) * 0.68 + wallOpen * 0.32, 0, 1)
	local rainExposure = math.clamp((1 - roofCover ^ 1.7) * 0.82 + wallOpen * 0.18, 0.06, 1)

	return {
		exposure = exposure,
		roofCover = roofCover,
		wallOpen = wallOpen,
		rainExposure = rainExposure,
		indoor = roofCover >= 0.7 and wallOpen < 0.7,
	}
end

function EnvironmentExposure.new(sampleInterval: number?): EnvironmentExposureState
	return setmetatable({
		_lastSampleAt = -math.huge,
		_sampleInterval = math.max(sampleInterval or 0.4, 0.1),
		_raycastParams = RaycastParams.new(),
		_state = {
			exposure = 1,
			roofCover = 0,
			wallOpen = 1,
			rainExposure = 1,
			indoor = false,
		},
	}, EnvironmentExposure)
end

function EnvironmentExposure:Sample(force: boolean?): State
	local now = os.clock()
	if force or now - self._lastSampleAt >= self._sampleInterval then
		self._state = sample(self)
		self._lastSampleAt = now
	end
	return self._state
end

function EnvironmentExposure:GetState(): State
	return self._state
end

return EnvironmentExposure