--!strict

--[[
	Pose

	A small value object for procedural weapon animation. Each pose carries the
	offsets needed by the viewmodel: main camera offset, gun offset, and arm weld
	offsets. Layers produce partial poses and WeaponAnimator blends/multiplies them.
]]

export type Pose = {
	Main: CFrame,
	Gun: CFrame,
	LeftArm: CFrame,
	RightArm: CFrame,
}

local Pose = {}

Pose.identity = {
	-- Identity pose means "do not move anything"; useful for disabled layers.
	Main = CFrame.identity,
	Gun = CFrame.identity,
	LeftArm = CFrame.identity,
	RightArm = CFrame.identity,
} :: Pose

function Pose.new(main: CFrame?, gun: CFrame?, leftArm: CFrame?, rightArm: CFrame?): Pose
	-- Missing offsets default to identity so a layer can return only the piece it
	-- owns, such as gun recoil or main camera bob.
	return {
		Main = main or CFrame.identity,
		Gun = gun or CFrame.identity,
		LeftArm = leftArm or CFrame.identity,
		RightArm = rightArm or CFrame.identity,
	}
end

function Pose.fromAnimationData(animationData): Pose
	-- Converts old ACS_Animations base CFrames into the new procedural pose shape.
	return Pose.new(
		animationData.MainCFrame,
		animationData.GunCFrame,
		animationData.LArmCFrame,
		animationData.RArmCFrame
	)
end

function Pose.multiply(left: Pose, right: Pose): Pose
	-- Layering uses CFrame multiplication so each effect composes on top of the
	-- current pose instead of replacing it.
	return {
		Main = left.Main * right.Main,
		Gun = left.Gun * right.Gun,
		LeftArm = left.LeftArm * right.LeftArm,
		RightArm = left.RightArm * right.RightArm,
	}
end

function Pose.lerp(fromPose: Pose, toPose: Pose, alpha: number): Pose
	-- Smooth final output to avoid twitchy layer changes.
	alpha = math.clamp(alpha, 0, 1)

	return {
		Main = fromPose.Main:Lerp(toPose.Main, alpha),
		Gun = fromPose.Gun:Lerp(toPose.Gun, alpha),
		LeftArm = fromPose.LeftArm:Lerp(toPose.LeftArm, alpha),
		RightArm = fromPose.RightArm:Lerp(toPose.RightArm, alpha),
	}
end

function Pose.withMain(main: CFrame): Pose
	return Pose.new(main)
end

function Pose.withGun(gun: CFrame): Pose
	return Pose.new(nil, gun)
end

return Pose
