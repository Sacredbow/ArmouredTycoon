--!strict

local Config = require(script.Parent.Parent.Config)
local Types = require(script.Parent.Parent.Types)

local definition: Types.MovementDefinition = {
	Name = "Fall",
	AnimationId = Config.Animations.Fall,
	WalkSpeed = Config.Speeds.Fall,
	BlendPosition = 0,
}

return definition
