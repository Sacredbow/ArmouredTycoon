local Runtime = require(script.Parent.Parent.RegistryComponents.Runtime)

local ACCESSORY_CONTAINER_NAMES = {
	Top = true,
	Helmet = true,
	Up = true,
	Down = true,
	Face = true,
	Olho = true,
	Headset = true,
	Numero = true,
	Vest = true,
	Chest = true,
	Waist = true,
	Back = true,
	Belt = true,
	Leg1 = true,
	Leg2 = true,
	Arm1 = true,
	Arm2 = true,
}

local BODY_PART_NAMES = {
	["Right Arm"] = true,
	["Left Arm"] = true,
	["Right Leg"] = true,
	["Left Leg"] = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	UpperTorso = true,
	LowerTorso = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
	Armor = true,
	EShield = true,
}

local function shouldIgnoreHit(part: BasePart): boolean
	local parent = part.Parent
	if not parent then
		return false
	end

	local isAccessory = parent:IsA("Accessory") or parent:IsA("Hat")
	local isCosmeticContainer = ACCESSORY_CONTAINER_NAMES[parent.Name] == true
	local isIgnoredPart = part.Transparency >= 1
		or not part.CanCollide
		or part.Name == "Ignorable"
		or part.Name == "Glass"
		or part.Name == "Ignore"

	return (isAccessory or isCosmeticContainer or isIgnoredPart) and not BODY_PART_NAMES[part.Name]
end

return function(context)
	local world = context.world
	local Components = context.Components

	for entity, projectile, previousPosition in world:query(Components.Projectile, Components.PreviousPosition) do
		local bullet = projectile.instance
		if not bullet or not bullet.Parent then
			world:delete(entity)
			continue
		end

		local currentPosition = bullet.Position
		local raycastParams = projectile.raycastParams
		if not raycastParams then
			raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = Runtime.getRaycastIgnoreList()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.IgnoreWater = true
			projectile.raycastParams = raycastParams
		end

		local result = workspace:Raycast(previousPosition, currentPosition - previousPosition, raycastParams)
		if result then
			local hitPart = result.Instance
			if hitPart:IsA("BasePart") and shouldIgnoreHit(hitPart) then
				local ignoredInstances = raycastParams.FilterDescendantsInstances
				table.insert(ignoredInstances, hitPart)
				raycastParams.FilterDescendantsInstances = ignoredInstances
				world:set(entity, Components.Projectile, projectile)
			else
				bullet:Destroy()
				world:delete(entity)
				continue
			end
		end

		world:set(entity, Components.PreviousPosition, currentPosition)
	end
end
