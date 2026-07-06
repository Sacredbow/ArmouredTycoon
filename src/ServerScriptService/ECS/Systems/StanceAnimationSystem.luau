local TweenService = game:GetService("TweenService")

local TWEEN_INFO = TweenInfo.new(0.3)

local function tweenJoint(joint: Motor6D?, c1: CFrame)
	if joint then
		TweenService:Create(joint, TWEEN_INFO, { C1 = c1 }):Play()
	end
end

local function getJoints(character: Model)
	local torso = character:FindFirstChild("Torso")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not torso or not rootPart then
		return nil
	end

	return {
		RootJoint = rootPart:FindFirstChild("RootJoint") :: Motor6D?,
		RightHip = torso:FindFirstChild("Right Hip") :: Motor6D?,
		LeftHip = torso:FindFirstChild("Left Hip") :: Motor6D?,
	}
end

local function applyProne(joints)
	tweenJoint(joints.RootJoint, CFrame.new(0, 1.5, 2.45) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(180)))
	tweenJoint(joints.RightHip, CFrame.new(0.5, 1, 0) * CFrame.Angles(math.rad(-5), math.rad(90), math.rad(0)))
	tweenJoint(joints.LeftHip, CFrame.new(-0.5, 1, 0) * CFrame.Angles(math.rad(-5), math.rad(-90), math.rad(0)))
end

local function applyLean(joints, stance: number, lean: number)
	if lean == 1 then
		if stance == 0 then
			tweenJoint(joints.RootJoint, CFrame.new(-1, 0, 0) * CFrame.Angles(math.rad(-90), math.rad(-15), math.rad(-180)))
			tweenJoint(joints.RightHip, CFrame.new(0.5, 1, 0) * CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)))
			tweenJoint(joints.LeftHip, CFrame.new(-0.5, 1, 0) * CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)))
		elseif stance == 1 then
			tweenJoint(joints.RootJoint, CFrame.new(-1, 0.75, 0.25) * CFrame.Angles(math.rad(-80), math.rad(-15), math.rad(-180)))
			tweenJoint(joints.RightHip, CFrame.new(0.5, 0, 0.4) * CFrame.Angles(math.rad(20), math.rad(90), math.rad(0)))
			tweenJoint(joints.LeftHip, CFrame.new(-0.5, 0, 0.4) * CFrame.Angles(math.rad(20), math.rad(-90), math.rad(0)))
		end
	elseif lean == -1 then
		if stance == 0 then
			tweenJoint(joints.RootJoint, CFrame.new(1, 0, 0) * CFrame.Angles(math.rad(-90), math.rad(15), math.rad(180)))
			tweenJoint(joints.RightHip, CFrame.new(0.5, 1, 0) * CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)))
			tweenJoint(joints.LeftHip, CFrame.new(-0.5, 1, 0) * CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)))
		elseif stance == 1 then
			tweenJoint(joints.RootJoint, CFrame.new(1, 0.75, 0.25) * CFrame.Angles(math.rad(-80), math.rad(15), math.rad(180)))
			tweenJoint(joints.RightHip, CFrame.new(0.5, 0, 0.4) * CFrame.Angles(math.rad(20), math.rad(90), math.rad(0)))
			tweenJoint(joints.LeftHip, CFrame.new(-0.5, 0, 0.4) * CFrame.Angles(math.rad(20), math.rad(-90), math.rad(0)))
		end
	elseif lean == 0 then
		if stance == 0 then
			tweenJoint(joints.RootJoint, CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(180)))
			tweenJoint(joints.RightHip, CFrame.new(0.5, 1, 0) * CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)))
			tweenJoint(joints.LeftHip, CFrame.new(-0.5, 1, 0) * CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)))
		elseif stance == 1 then
			tweenJoint(joints.RootJoint, CFrame.new(0, 1, 0.25) * CFrame.Angles(math.rad(-80), math.rad(0), math.rad(180)))
			tweenJoint(joints.RightHip, CFrame.new(0.5, 0, 0.4) * CFrame.Angles(math.rad(20), math.rad(90), math.rad(0)))
			tweenJoint(joints.LeftHip, CFrame.new(-0.5, 0, 0.4) * CFrame.Angles(math.rad(20), math.rad(-90), math.rad(0)))
		end
	end
end

return function(context)
	local world = context.world
	local Components = context.Components

	for entity, stanceState in world:query(Components.StanceState) do
		local appliedKey = `{stanceState.stance}:{stanceState.lean}:{stanceState.updatedAt}`
		if stanceState.appliedKey == appliedKey then
			continue
		end

		local character = stanceState.character
		if not character or not character.Parent then
			world:delete(entity)
			continue
		end

		local joints = getJoints(character)
		if not joints or not joints.RootJoint or not joints.RightHip or not joints.LeftHip then
			continue
		end

		if stanceState.stance == 2 then
			applyProne(joints)
		end

		applyLean(joints, stanceState.stance, stanceState.lean)

		stanceState.appliedKey = appliedKey
		world:set(entity, Components.StanceState, stanceState)
	end
end
