--!strict

--[[
	HitResolver

	Translates a hit part into the ACS body-region damage code expected by the
	server damage event. Keeping this tiny mapping isolated makes future armor,
	limb, or headshot logic easier to expand without touching CastRay directly.
]]

const HitResolver = {}

export type HumanoidSearchResult = {
	found: boolean,
	humanoid: Humanoid?,
}

const HEAD_PARTS = {
	Head = true,
}

const TORSO_PARTS = {
	Torso = true,
	UpperTorso = true,
	LowerTorso = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
}

const LEG_PARTS = {
	["Right Leg"] = true,
	["Left Leg"] = true,
	RightLeg = true,
	LeftLeg = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
}

local function hasNamedAncestor(part: Instance, name: string): boolean
	local parent = part.Parent
	return parent ~= nil and parent.Name == name
end

-- Checks the hit part and one parent above it, matching the old framework behavior
-- while also handling nested authored armor/body folders.
function HitResolver.findHumanoid(hitPart: Instance?): HumanoidSearchResult
	if not hitPart then
		return {
			found = false,
			humanoid = nil,
		}
	end

	local parent = hitPart.Parent
	local grandParent = parent and parent.Parent
	local humanoid = if hitPart:IsA("Humanoid")
		then hitPart
		elseif parent then parent:FindFirstChildOfClass("Humanoid")
		else nil

	if not humanoid and grandParent then
		humanoid = grandParent:FindFirstChildOfClass("Humanoid")
	end

	return {
		found = humanoid ~= nil,
		humanoid = humanoid,
	}
end

function HitResolver.getLimbType(hitPart: Instance?): number?
	if not hitPart then
		return nil
	end

	if HEAD_PARTS[hitPart.Name]
		or hasNamedAncestor(hitPart, "Top")
		or hasNamedAncestor(hitPart, "Headset")
		or hasNamedAncestor(hitPart, "Olho")
		or hasNamedAncestor(hitPart, "Face")
		or hasNamedAncestor(hitPart, "Numero")
	then
		return 1
	end

	if TORSO_PARTS[hitPart.Name]
		or hasNamedAncestor(hitPart, "Chest")
		or hasNamedAncestor(hitPart, "Waist")
	then
		return 2
	end

	if LEG_PARTS[hitPart.Name] then
		return 3
	end

	return nil
end

return HitResolver