--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RoofSampleOffsets = {
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

local WallDirections = {
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

local EnvironmentExposure = {
	LastSampleAt = -math.huge,
	SampleInterval = 0.4,
	State = {
		exposure = 1,
		roofCover = 0,
		wallOpen = 1,
		rainExposure = 1,
		indoor = false,
	},
	RaycastParams = RaycastParams.new(),
}

local function GetListenerPosition(): (Vector3?, Model?)
	local Camera = Workspace.CurrentCamera
	local Character = Players.LocalPlayer.Character
	if Camera then
		return Camera.CFrame.Position, Character
	end

	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	if Root and Root:IsA("BasePart") then
		return Root.Position, Character
	end

	return nil, Character
end

local function SampleState(): State
	local Position, Character = GetListenerPosition()
	if not Position then
		return EnvironmentExposure.State
	end

	local Params = EnvironmentExposure.RaycastParams
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = if Character then { Character } else {}
	Params.IgnoreWater = true

	local RoofHits = 0
	for _, Offset in RoofSampleOffsets do
		if Workspace:Raycast(Position + Offset, Vector3.new(0, 180, 0), Params) then
			RoofHits += 1
		end
	end

	local OpenWalls = 0
	for _, Direction in WallDirections do
		if not Workspace:Raycast(Position, Direction * 75, Params) then
			OpenWalls += 1
		end
	end

	local RoofCover = RoofHits / #RoofSampleOffsets
	local WallOpen = OpenWalls / #WallDirections
	local Exposure = math.clamp((1 - RoofCover) * 0.68 + WallOpen * 0.32, 0, 1)
	local RainExposure = math.clamp((1 - RoofCover ^ 1.7) * 0.82 + WallOpen * 0.18, 0.06, 1)

	return {
		exposure = Exposure,
		roofCover = RoofCover,
		wallOpen = WallOpen,
		rainExposure = RainExposure,
		indoor = RoofCover >= 0.7 and WallOpen < 0.7,
	}
end

function EnvironmentExposure.Init(SampleInterval: number?)
	EnvironmentExposure.LastSampleAt = -math.huge
	EnvironmentExposure.SampleInterval = math.max(SampleInterval or 0.4, 0.1)
	EnvironmentExposure.RaycastParams = RaycastParams.new()
	return EnvironmentExposure
end

function EnvironmentExposure.Sample(Force: boolean?): State
	local Now = os.clock()
	if Force or Now - EnvironmentExposure.LastSampleAt >= EnvironmentExposure.SampleInterval then
		EnvironmentExposure.State = SampleState()
		EnvironmentExposure.LastSampleAt = Now
	end
	return EnvironmentExposure.State
end

function EnvironmentExposure.GetState(): State
	return EnvironmentExposure.State
end

return EnvironmentExposure
