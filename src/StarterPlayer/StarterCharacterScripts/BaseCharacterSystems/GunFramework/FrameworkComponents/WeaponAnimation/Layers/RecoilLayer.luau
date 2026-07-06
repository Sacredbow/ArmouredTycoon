--!strict

--[[
	RecoilLayer

	Procedural pose recoil. This is separate from camera recoil: it moves the
	viewmodel/gun/arms so shots feel physical even when camera motion is reduced.
]]

local Pose = require(script.Parent.Parent.Pose)
local Spring = require(script.Parent.Parent.Spring)

local RecoilLayer = {}
RecoilLayer.__index = RecoilLayer

export type RecoilLayer = typeof(setmetatable({} :: {
	_offset: any,
}, RecoilLayer))

function RecoilLayer.new(): RecoilLayer
	return setmetatable({
		_offset = Spring.new(Vector3.zero, 24, 0.72),
	}, RecoilLayer)
end

function RecoilLayer:Fire(power: number?)
	-- Add a randomized angular impulse so repeated shots do not look identical.
	local amount = power or 1
	self._offset:Impulse(Vector3.new(
		math.rad(4.8 * amount),
		math.rad((math.random() - 0.5) * 2.2 * amount),
		math.rad((math.random() - 0.5) * 1.4 * amount)
	))
end

function RecoilLayer:Evaluate(deltaTime: number): Pose.Pose
	-- Spring target returns to zero every frame, creating natural recovery.
	self._offset:SetTarget(Vector3.zero)
	local offset = self._offset:Update(deltaTime)

	local kickback = math.abs(offset.X)
	-- Main pose gets the largest impulse; gun and arms receive smaller matching
	-- offsets so the whole rig feels connected.
	local main =
		CFrame.Angles(offset.X, offset.Y, offset.Z)
		* CFrame.new(0, 0, kickback * 0.18)

	local gun =
		CFrame.Angles(offset.X * 0.32, offset.Y * 0.3, offset.Z * 0.22)
		* CFrame.new(0, 0, kickback * 0.08)

	local leftArm =
		CFrame.Angles(-offset.X * 0.08, offset.Y * 0.05, -offset.Z * 0.08)
		* CFrame.new(0, kickback * 0.01, 0)

	local rightArm =
		CFrame.Angles(offset.X * 0.16, offset.Y * 0.12, offset.Z * 0.1)
		* CFrame.new(0, 0, kickback * 0.03)

	return Pose.new(main, gun, leftArm, rightArm)
end

return RecoilLayer
