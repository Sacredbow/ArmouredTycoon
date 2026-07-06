--!strict

--[[
	HitResolver

	Translates a hit part into the ACS body-region damage code expected by the
	server damage event. Keeping this tiny mapping isolated makes future armor,
	limb, or headshot logic easier to expand without touching CastRay directly.
]]

local HitResolver = {}

export type HumanoidSearchResult = {
	found: boolean,
	humanoid: Humanoid?,
}

-- checks the hit part and one parent above it, matching the old framework behavior
function HitResolver.findHumanoid(hitPart: Instance?): HumanoidSearchResult
	if not hitPart then
		return {
			found = false,
			humanoid = nil,
		}
	end

	local parent = hitPart.Parent
	local grandParent = parent and parent.Parent
	local humanoid = if parent then parent:FindFirstChildOfClass("Humanoid") else nil

	if not humanoid and grandParent then
		humanoid = grandParent:FindFirstChildOfClass("Humanoid")
	end

	return {
		found = humanoid ~= nil,
		humanoid = humanoid,
	}
end

return HitResolver
