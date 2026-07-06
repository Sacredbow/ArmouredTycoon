--!strict

--[[
	AnimationRunner

	Runs legacy ACS animation functions with a named error boundary. Weapon
	animation modules are still authored as imperative functions, so this wrapper
	gives us safer failure reporting without rewriting every weapon at once.
]]

local AnimationRunner = {}

export type AnimationContext = {
	any
}

function AnimationRunner.run(animationName: string, callback: () -> ()): boolean
	-- xpcall preserves a useful traceback, which matters because animation errors
	-- usually come from a weapon-specific ACS_Animations module.
	local ok, result = xpcall(callback, debug.traceback)
	if not ok then
		warn(("[ACS Animation] %s failed:\n%s"):format(animationName, tostring(result)))
		return false
	end

	return true
end

return AnimationRunner
