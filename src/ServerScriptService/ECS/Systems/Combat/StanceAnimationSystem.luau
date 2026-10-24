--!strict
--[[
	@class StanceAnimationSystem

	@desc
	Applies stance / lean pose tweens to character joints based on
	StanceState entities (standing, crouching, prone, leaning).
]]

--// Services

const TweenService = game:GetService("TweenService")
--// Constants

const TWEEN_INFO = TweenInfo.new(0.3)
--// Micro-Optimisations

const math_rad = math.rad
const CFrame_new = CFrame.new
const CFrame_Angles = CFrame.Angles
--// Internal Utilities

local function TweenJoint(Joint: Motor6D?, C1: CFrame)
	if Joint then
		TweenService:Create(Joint, TWEEN_INFO, { C1 = C1 }):Play()
	end
end

local function GetJoints(Character: Model)
	const Torso = Character:FindFirstChild("Torso")
	const RootPart = Character:FindFirstChild("HumanoidRootPart")
	if not Torso or not RootPart then
		return nil
	end

	return {
		RootJoint = RootPart:FindFirstChild("RootJoint") :: Motor6D?,
		RightHip = Torso:FindFirstChild("Right Hip") :: Motor6D?,
		LeftHip = Torso:FindFirstChild("Left Hip") :: Motor6D?,
	}
end

local function ApplyProne(Joints)
	TweenJoint(Joints.RootJoint, CFrame_new(0, 1.5, 2.45) * CFrame_Angles(math_rad(0), math_rad(0), math_rad(180)))
	TweenJoint(Joints.RightHip, CFrame_new(0.5, 1, 0) * CFrame_Angles(math_rad(-5), math_rad(90), math_rad(0)))
	TweenJoint(Joints.LeftHip, CFrame_new(-0.5, 1, 0) * CFrame_Angles(math_rad(-5), math_rad(-90), math_rad(0)))
end

local function ApplyLean(Joints, Stance: number, Lean: number)
	if Lean == 1 then
		if Stance == 0 then
			TweenJoint(
				Joints.RootJoint,
				CFrame_new(-1, 0, 0) * CFrame_Angles(math_rad(-90), math_rad(-15), math_rad(-180))
			)
			TweenJoint(Joints.RightHip, CFrame_new(0.5, 1, 0) * CFrame_Angles(math_rad(0), math_rad(90), math_rad(0)))
			TweenJoint(Joints.LeftHip, CFrame_new(-0.5, 1, 0) * CFrame_Angles(math_rad(0), math_rad(-90), math_rad(0)))
		elseif Stance == 1 then
			TweenJoint(
				Joints.RootJoint,
				CFrame_new(-1, 0.75, 0.25) * CFrame_Angles(math_rad(-80), math_rad(-15), math_rad(-180))
			)
			TweenJoint(
				Joints.RightHip,
				CFrame_new(0.5, 0, 0.4) * CFrame_Angles(math_rad(20), math_rad(90), math_rad(0))
			)
			TweenJoint(
				Joints.LeftHip,
				CFrame_new(-0.5, 0, 0.4) * CFrame_Angles(math_rad(20), math_rad(-90), math_rad(0))
			)
		end
	elseif Lean == -1 then
		if Stance == 0 then
			TweenJoint(
				Joints.RootJoint,
				CFrame_new(1, 0, 0) * CFrame_Angles(math_rad(-90), math_rad(15), math_rad(180))
			)
			TweenJoint(Joints.RightHip, CFrame_new(0.5, 1, 0) * CFrame_Angles(math_rad(0), math_rad(90), math_rad(0)))
			TweenJoint(Joints.LeftHip, CFrame_new(-0.5, 1, 0) * CFrame_Angles(math_rad(0), math_rad(-90), math_rad(0)))
		elseif Stance == 1 then
			TweenJoint(
				Joints.RootJoint,
				CFrame_new(1, 0.75, 0.25) * CFrame_Angles(math_rad(-80), math_rad(15), math_rad(180))
			)
			TweenJoint(
				Joints.RightHip,
				CFrame_new(0.5, 0, 0.4) * CFrame_Angles(math_rad(20), math_rad(90), math_rad(0))
			)
			TweenJoint(
				Joints.LeftHip,
				CFrame_new(-0.5, 0, 0.4) * CFrame_Angles(math_rad(20), math_rad(-90), math_rad(0))
			)
		end
	elseif Lean == 0 then
		if Stance == 0 then
			TweenJoint(Joints.RootJoint, CFrame_new(0, 0, 0) * CFrame_Angles(math_rad(-90), math_rad(0), math_rad(180)))
			TweenJoint(Joints.RightHip, CFrame_new(0.5, 1, 0) * CFrame_Angles(math_rad(0), math_rad(90), math_rad(0)))
			TweenJoint(Joints.LeftHip, CFrame_new(-0.5, 1, 0) * CFrame_Angles(math_rad(0), math_rad(-90), math_rad(0)))
		elseif Stance == 1 then
			TweenJoint(
				Joints.RootJoint,
				CFrame_new(0, 1, 0.25) * CFrame_Angles(math_rad(-80), math_rad(0), math_rad(180))
			)
			TweenJoint(
				Joints.RightHip,
				CFrame_new(0.5, 0, 0.4) * CFrame_Angles(math_rad(20), math_rad(90), math_rad(0))
			)
			TweenJoint(
				Joints.LeftHip,
				CFrame_new(-0.5, 0, 0.4) * CFrame_Angles(math_rad(20), math_rad(-90), math_rad(0))
			)
		end
	end
end

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components

	for Entity, StanceState in World:query(Components.StanceState) do
		const AppliedKey = `{StanceState.stance}:{StanceState.lean}:{StanceState.updatedAt}`
		if StanceState.appliedKey == AppliedKey then
			continue
		end

		const Character = StanceState.character
		if not Character or not Character.Parent then
			World:delete(Entity)
			continue
		end

		const Joints = GetJoints(Character)
		if not Joints or not Joints.RootJoint or not Joints.RightHip or not Joints.LeftHip then
			continue
		end

		if StanceState.stance == 2 then
			ApplyProne(Joints)
		end

		ApplyLean(Joints, StanceState.stance, StanceState.lean)

		StanceState.appliedKey = AppliedKey
		World:set(Entity, Components.StanceState, StanceState)
	end
end
