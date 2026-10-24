--!strict

--[[
	SwayLayer

	Camera-turn inertia layer. It reads camera CFrame deltas and turns them into a
	small delayed weapon rotation. ADS disables this so aiming remains controlled.
]]

local Pose = require(script.Parent.Parent.Pose)
local Spring = require(script.Parent.Parent.Spring)

local SwayLayer = {}
SwayLayer.__index = SwayLayer

export type SwayLayer = typeof(setmetatable(
	{} :: {
		_rotation: any,
		_lastCameraCFrame: CFrame?,
	},
	SwayLayer
))

function SwayLayer.new(): SwayLayer
	return setmetatable({
		_rotation = Spring.new(Vector3.zero, 20, 0.82),
		_lastCameraCFrame = nil,
	}, SwayLayer)
end

function SwayLayer:Evaluate(deltaTime: number, cameraCFrame: CFrame, isAiming: boolean): Pose.Pose
	-- Store the previous camera frame first so next evaluation can measure delta.
	local previous = self._lastCameraCFrame
	self._lastCameraCFrame = cameraCFrame

	if isAiming then
		-- No camera lag while aiming; the weapon should stay centered on sight.
		self._rotation:Snap(Vector3.zero)
		return Pose.identity
	end

	if not previous then
		return Pose.identity
	end

	local delta = previous:ToObjectSpace(cameraCFrame)
	-- Convert camera rotation delta into a clamped target. This prevents sudden
	-- mouse flicks from throwing arms/gun too far off screen.
	local x, y, _z = delta:ToOrientation()
	local aimMultiplier = 1
	local maxSway = 0.12
	local target = Vector3.new(
		math.clamp(-x * aimMultiplier, -maxSway, maxSway),
		math.clamp(-y * aimMultiplier, -maxSway, maxSway),
		0
	)

	self._rotation:SetTarget(target)
	local rotation = self._rotation:Update(deltaTime)
	local poseMultiplier = 1

	local main = CFrame.Angles(
		rotation.X * 0.65 * poseMultiplier,
		rotation.Y * 0.85 * poseMultiplier,
		rotation.Y * 0.25 * poseMultiplier
	)
	local gun = CFrame.Angles(
		rotation.X * 0.18 * poseMultiplier,
		rotation.Y * 0.22 * poseMultiplier,
		rotation.Y * 0.08 * poseMultiplier
	)
	local leftArm = CFrame.Angles(
		-rotation.X * 0.12 * poseMultiplier,
		rotation.Y * 0.1 * poseMultiplier,
		-rotation.Y * 0.08 * poseMultiplier
	)
	local rightArm = CFrame.Angles(
		rotation.X * 0.08 * poseMultiplier,
		rotation.Y * 0.08 * poseMultiplier,
		rotation.Y * 0.05 * poseMultiplier
	)

	return Pose.new(main, gun, leftArm, rightArm)
end

function SwayLayer:Reset(cameraCFrame: CFrame?)
	-- Reset both spring and baseline camera so ADS transitions do not inherit old
	-- camera deltas.
	self._rotation:Snap(Vector3.zero)
	self._lastCameraCFrame = cameraCFrame
end

return SwayLayer
