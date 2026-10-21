--!strict

--[[
	InputBindings

	Owns framework-level movement/combat action names. Main still handles what
	each action means, but this module keeps the raw ContextActionService binding
	list from being scattered through the weapon script.
]]

local InputBindings = {}

export type ActionHandler = (string, Enum.UserInputState, InputObject) -> ()

-- Default actions are always available to the character controller layer.
-- Weapon-specific actions like fire/reload/ADS are still bound on equip in Main.
function InputBindings.bindDefaultActions(contextActionService: ContextActionService, actionHandler: ActionHandler)
	contextActionService:BindAction("Run", actionHandler, false, Enum.KeyCode.LeftShift)
	contextActionService:BindAction("Stand", actionHandler, false, Enum.KeyCode.X)
	contextActionService:BindAction("Crouch", actionHandler, false, Enum.KeyCode.C)
	contextActionService:BindAction("ToggleWalk", actionHandler, false, Enum.KeyCode.Z)
end

function InputBindings.unbindDefaultActions(contextActionService: ContextActionService)
	contextActionService:UnbindAction("Run")
	contextActionService:UnbindAction("Stand")
	contextActionService:UnbindAction("Crouch")
	contextActionService:UnbindAction("ToggleWalk")
end
return InputBindings
