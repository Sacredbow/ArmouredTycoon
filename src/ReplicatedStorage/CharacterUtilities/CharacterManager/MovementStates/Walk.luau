--!strict

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

-- walk sits at the low end of the 1d movement blend
local definition: Types.MovementDefinition = {
	Name = "Walk",
	AnimationId = Config.Animations.Walk,
	WalkSpeed = Config.Speeds.Walk,
	BlendPosition = 0,
}

return definition
