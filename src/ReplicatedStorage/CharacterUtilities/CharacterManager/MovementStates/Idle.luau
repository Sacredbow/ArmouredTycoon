--!strict

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

-- idle is still a movement layer so it can fade cleanly into walking
local definition: Types.MovementDefinition = {
	Name = "Idle",
	AnimationId = Config.Animations.Idle,
	WalkSpeed = Config.Speeds.Idle,
	BlendPosition = 0,
}

return definition
