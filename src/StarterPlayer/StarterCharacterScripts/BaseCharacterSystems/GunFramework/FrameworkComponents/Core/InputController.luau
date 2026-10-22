--!strict
--[[
	@class InputController

	@desc
	Owns all weapon-specific ContextActionService bindings and mouse wheel
	handlers. Dispatches to callbacks provided by Main so the input layer
	never holds weapon state directly.
]]

--// Services

const ContextActionService = game:GetService("ContextActionService")
const UserInputService = game:GetService("UserInputService")

local InputController = {}
InputController.__index = InputController

export type ActionHandler = (actionName: string, inputState: Enum.UserInputState, inputObject: InputObject) -> ()

export type InputController = typeof(setmetatable({} :: {
	_player: Player,
	_mouse: Mouse,
	_handler: ActionHandler?,
	_wheelForwardConn: RBXScriptConnection?,
	_wheelBackwardConn: RBXScriptConnection?,
}, InputController))

function InputController.new(player: Player, mouse: Mouse): InputController
	return setmetatable({
		_player = player,
		_mouse = mouse,
		_handler = nil,
		_wheelForwardConn = nil,
		_wheelBackwardConn = nil,
	}, InputController)
end

--// Public API

function InputController:bindWeaponActions(handler: ActionHandler)
	self._handler = handler

	ContextActionService:BindAction("Fire", handler, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("ADS", handler, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	ContextActionService:BindAction("Reload", handler, true, Enum.KeyCode.R, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("CycleFiremode", handler, false, Enum.KeyCode.V)

	ContextActionService:SetPosition("Reload", UDim2.new(0.8, 0, 0.2, 0))
	ContextActionService:SetImage("Reload", "rbxassetid://134368074293877")
	ContextActionService:SetImage("Fire", "rbxassetid://99203026125033")
	ContextActionService:SetImage("ADS", "rbxassetid://632007943")

	-- Mouse wheel
	self:_bindWheel()
end

function InputController:unbindWeaponActions()
	ContextActionService:UnbindAction("Fire")
	ContextActionService:UnbindAction("ADS")
	ContextActionService:UnbindAction("Reload")
	ContextActionService:UnbindAction("CycleFiremode")

	self:_unbindWheel()
	self._handler = nil
end

function InputController:bindBipodToggle(handler: ActionHandler)
	ContextActionService:BindAction("ToggleBipod", handler, true, Enum.KeyCode.B)
end

function InputController:unbindBipodToggle()
	ContextActionService:UnbindAction("ToggleBipod")
end

function InputController:destroy()
	self:unbindWeaponActions()
	self:unbindBipodToggle()
	self._handler = nil
end

--// Internal

function InputController:_bindWheel()
	self:_unbindWheel()

	self._wheelBackwardConn = self._mouse.WheelBackward:Connect(function()
		if self._handler then
			self._handler("WheelBackward", Enum.UserInputState.Begin, nil)
		end
	end)

	self._wheelForwardConn = self._mouse.WheelForward:Connect(function()
		if self._handler then
			self._handler("WheelForward", Enum.UserInputState.Begin, nil)
		end
	end)
end

function InputController:_unbindWheel()
	if self._wheelBackwardConn then
		self._wheelBackwardConn:Disconnect()
		self._wheelBackwardConn = nil
	end
	if self._wheelForwardConn then
		self._wheelForwardConn:Disconnect()
		self._wheelForwardConn = nil
	end
end

return InputController
