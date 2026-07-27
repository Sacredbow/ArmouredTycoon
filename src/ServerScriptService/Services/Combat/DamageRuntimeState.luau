--!strict

local LastDamagerByHumanoid: { [Humanoid]: number } = {}
local CleanupByHumanoid: { [Humanoid]: RBXScriptConnection } = {}

local DamageRuntimeState = {}

local function clearHumanoid(humanoid: Humanoid)
	LastDamagerByHumanoid[humanoid] = nil

	local connection = CleanupByHumanoid[humanoid]
	if connection then
		connection:Disconnect()
		CleanupByHumanoid[humanoid] = nil
	end
end

local function bindCleanup(humanoid: Humanoid)
	if CleanupByHumanoid[humanoid] then
		return
	end

	CleanupByHumanoid[humanoid] = humanoid.Destroying:Connect(function()
		clearHumanoid(humanoid)
	end)
end

function DamageRuntimeState.SetLastDamager(humanoid: Humanoid, userId: number)
	LastDamagerByHumanoid[humanoid] = userId
	bindCleanup(humanoid)
end

function DamageRuntimeState.GetLastDamager(humanoid: Humanoid): number?
	return LastDamagerByHumanoid[humanoid]
end

function DamageRuntimeState.ClearHumanoid(humanoid: Humanoid)
	clearHumanoid(humanoid)
end

return DamageRuntimeState
