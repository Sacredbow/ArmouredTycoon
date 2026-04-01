local Idle = {}
local ID = "rbxassetid://115530404426830"

function Idle.Enter(manager)
	manager:PlayAnimation(ID, true)
	manager.Humanoid.WalkSpeed = 16
end

return Idle
