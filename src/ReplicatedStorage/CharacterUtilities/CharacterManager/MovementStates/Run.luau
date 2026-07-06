--!strict

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

-- run sits at the high end of the 1d movement blend
local definition: Types.MovementDefinition = {
	Name = "Run",
	AnimationId = Config.Animations.Run,
	WalkSpeed = Config.Speeds.Run,
	BlendPosition = 1,
}

return definition
