--!strict

--[[
	BobLayer

	Movement bob for walking and sprinting. The intensity is spring-smoothed so
	weapon motion ramps in/out instead of popping when the player starts moving.
]]

local Pose = require(script.Parent.Parent.Pose)
local Spring = require(script.Parent.Parent.Spring)

local BobLayer = {}
BobLayer.__index = BobLayer

export type BobLayer = typeof(setmetatable(
	{} :: {
		_intensity: any,
	},
	BobLayer
))

function BobLayer.new(): BobLayer
	return setmetatable({
		_intensity = Spring.new(0, 12, 0.86),
	}, BobLayer)
end

function BobLayer:Evaluate(deltaTime: number, moveSpeed: number, isSprinting: boolean): Pose.Pose
	-- Sprinting allows a stronger target, but the spring still prevents instant
	-- full-strength bob.
	local maxIntensity = if isSprinting then 1.35 else 0.8
	local target = math.clamp(moveSpeed / 18, 0, maxIntensity)
	self._intensity:SetTarget(target)
	local intensity = self._intensity:Update(deltaTime)

	if intensity <= 0.001 then
		return Pose.identity
	end

	local t = os.clock()
	-- Sine/cosine pair gives a simple footstep-like loop with vertical lift and
	-- side roll.
	local rate = if isSprinting then 11 else 7.5
	local x = math.sin(t * rate) * 0.018 * intensity
	local y = math.abs(math.cos(t * rate)) * 0.028 * intensity
	local roll = math.sin(t * rate) * (if isSprinting then 1.15 else 0.55) * intensity
	local pitch = math.cos(t * rate * 0.5) * 0.35 * intensity

	local main = CFrame.new(x, -y, 0) * CFrame.Angles(math.rad(pitch), 0, math.rad(roll))

	local gun = CFrame.new(x * 0.35, -y * 0.18, 0) * CFrame.Angles(math.rad(pitch * 0.25), 0, math.rad(roll * 0.3))

	local leftArm = CFrame.new(-x * 0.25, y * 0.12, 0)
		* CFrame.Angles(math.rad(-pitch * 0.12), 0, math.rad(-roll * 0.16))

	local rightArm = CFrame.new(x * 0.18, y * 0.08, 0) * CFrame.Angles(math.rad(pitch * 0.1), 0, math.rad(roll * 0.12))

	return Pose.new(main, gun, leftArm, rightArm)
end

function BobLayer:Reset()
	-- ADS calls this so movement bob does not pull the sight picture off target.
	self._intensity:Snap(0)
end

return BobLayer
