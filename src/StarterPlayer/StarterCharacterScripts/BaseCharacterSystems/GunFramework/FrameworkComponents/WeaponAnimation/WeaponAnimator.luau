--!strict

--[[
	WeaponAnimator

	Procedural first-person pose blender. The ACS animation modules still
	control authored reload/equip motions, but this animator layers continuous feel
	on top: idle breathing, movement bob, camera sway, and recoil.

	Important aiming rule:
		When aiming, bob and sway reset so the sight picture stays stable. Recoil
		still applies because shots should visibly kick even in ADS.
]]

local Pose = require(script.Parent.Pose)
local IdleLayer = require(script.Parent.Layers.IdleLayer)
local BobLayer = require(script.Parent.Layers.BobLayer)
local SwayLayer = require(script.Parent.Layers.SwayLayer)
local RecoilLayer = require(script.Parent.Layers.RecoilLayer)

local WeaponAnimator = {}
WeaponAnimator.__index = WeaponAnimator

export type WeaponAnimator = typeof(setmetatable(
	{} :: {
		_basePose: Pose.Pose,
		_currentPose: Pose.Pose,
		_idleLayer: any,
		_bobLayer: any,
		_swayLayer: any,
		_recoilLayer: any,
	},
	WeaponAnimator
))

export type EvaluateContext = {
	deltaTime: number,
	cameraCFrame: CFrame,
	moveSpeed: number,
	isSprinting: boolean,
	isAiming: boolean,
	isBusy: boolean,
}

function WeaponAnimator.new(animationData): WeaponAnimator
	-- Base pose comes from the weapon's ACS_Animations module so every weapon can
	-- keep its authored hand/gun offsets.
	local basePose = Pose.fromAnimationData(animationData)

	return setmetatable({
		_basePose = basePose,
		_currentPose = basePose,
		_idleLayer = IdleLayer.new(),
		_bobLayer = BobLayer.new(),
		_swayLayer = SwayLayer.new(),
		_recoilLayer = RecoilLayer.new(),
	}, WeaponAnimator)
end

function WeaponAnimator:Fire(power: number?)
	-- Recoil is exposed as a simple event; the recoil layer owns the spring.
	self._recoilLayer:Fire(power)
end

function WeaponAnimator:SetBasePose(basePose: Pose.Pose)
	self._basePose = basePose
end

function WeaponAnimator:Evaluate(context: EvaluateContext): Pose.Pose
	-- Clamp dt so a hitch does not create a giant weapon offset on the next frame.
	local deltaTime = math.clamp(context.deltaTime, 0, 1 / 20)

	if context.isAiming then
		-- ADS must be stable. Movement bob and camera sway are reset here so the
		-- gun does not drift away from the sight picture while aiming.
		self._bobLayer:Reset()
		self._swayLayer:Reset(context.cameraCFrame)

		local aimedPose = Pose.multiply(self._basePose, self._recoilLayer:Evaluate(deltaTime))
		self._currentPose = aimedPose
		return aimedPose
	end

	local idleWeight = if context.isBusy or context.isSprinting then 0 else 1

	-- Layer order matters: start from authored pose, add idle, then movement,
	-- then camera sway, then recoil on top.
	local pose = self._basePose
	pose = Pose.multiply(pose, self._idleLayer:Evaluate(idleWeight))
	pose = Pose.multiply(pose, self._bobLayer:Evaluate(deltaTime, context.moveSpeed, context.isSprinting))
	pose = Pose.multiply(pose, self._swayLayer:Evaluate(deltaTime, context.cameraCFrame, false))
	pose = Pose.multiply(pose, self._recoilLayer:Evaluate(deltaTime))

	self._currentPose = Pose.lerp(self._currentPose, pose, 1 - math.exp(-18 * deltaTime))
	return self._currentPose
end

function WeaponAnimator:GetBasePose(): Pose.Pose
	return self._basePose
end

return WeaponAnimator
