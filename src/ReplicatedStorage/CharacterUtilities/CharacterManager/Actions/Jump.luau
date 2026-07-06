--!strict

local Config = require(script.Parent.Parent.Config)

local Jump = {}

function Jump.Do(manager)
	-- jump is intentionally tiny, the manager owns timing and cleanup
	manager:PlayActionAnimation(Config.Animations.Jump, Enum.AnimationPriority.Action)
end

return Jump
