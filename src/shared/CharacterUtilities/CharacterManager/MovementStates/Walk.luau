local Walk = {}
local ID = "rbxassetid://130057488609165"

function Walk.Enter(manager)
	manager:PlayAnimation(ID, true)
	manager.Humanoid.WalkSpeed = 16
end

return Walk
