--!strict

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local definition: Types.MovementDefinition = {
	Name = "Climb",
	AnimationId = Config.Animations.Climb,
	WalkSpeed = Config.Speeds.Climb,
	BlendPosition = 0,
}

return definition
