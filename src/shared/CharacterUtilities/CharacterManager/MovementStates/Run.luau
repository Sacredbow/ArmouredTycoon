local Run = {}
local ID = "rbxassetid://98558046780012"

function Run.Enter(manager)
	manager:PlayAnimation(ID, true)
	manager.Humanoid.WalkSpeed = 30
end

return Run
