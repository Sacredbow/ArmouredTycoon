--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = script:FindFirstAncestorOfClass("Model")
if not character then
	error("[BaseMovement] Character model ancestor was not found")
end

local ECS = require(ReplicatedStorage.ECS)
local CharacterManager = require(ReplicatedStorage.CharacterUtilities.CharacterManager)
local CharacterRegistry = require(ReplicatedStorage.CharacterUtilities.CharacterRegistry)
local manager = CharacterManager.new(character)
local characterEntity = ECS.createEntity({
	Name = `{player.Name}:Character`,
	Model = character,
	Character = character,
})
CharacterRegistry.Register(characterEntity, manager)

-- wasd and arrows feed the same movement snapshot
local KEY_TO_DIRECTION = {
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.Up] = "W",
	[Enum.KeyCode.A] = "A",
	[Enum.KeyCode.Left] = "A",
	[Enum.KeyCode.S] = "S",
	[Enum.KeyCode.Down] = "S",
	[Enum.KeyCode.D] = "D",
	[Enum.KeyCode.Right] = "D",
}

local function bindSprintButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local boundButton: GuiButton? = nil

	local function tryBind(instance: Instance?)
		if boundButton or not instance or not instance:IsA("GuiButton") or instance.Name ~= "SprintButton" then
			return
		end

		boundButton = instance
		instance.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				manager:SetRunning(true)
			end
		end)

		instance.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				manager:SetRunning(false)
			end
		end)
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		tryBind(descendant)
		if boundButton then
			return
		end
	end

	local connection: RBXScriptConnection?
	connection = playerGui.DescendantAdded:Connect(function(descendant)
		tryBind(descendant)
		if boundButton and connection then
			connection:Disconnect()
		end
	end)
end

local function setMoveKeyFromInput(keyCode: Enum.KeyCode, isPressed: boolean)
	local direction = KEY_TO_DIRECTION[keyCode]
	if direction then
		manager:SetMoveKey(direction :: "W" | "A" | "S" | "D", isPressed)
	end
end

bindSprintButton()

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	setMoveKeyFromInput(input.KeyCode, true)

	-- sprint and jump are separate flags so ui buttons can use them too
	if input.KeyCode == Enum.KeyCode.LeftShift then
		manager:SetRunning(true)
	elseif input.KeyCode == Enum.KeyCode.Space then
		manager:SetJumpHeld(true)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
	-- Always release held input; UI focus can consume the key-up event.
	setMoveKeyFromInput(input.KeyCode, false)

	if input.KeyCode == Enum.KeyCode.LeftShift then
		manager:SetRunning(false)
	elseif input.KeyCode == Enum.KeyCode.Space then
		manager:SetJumpHeld(false)
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	-- losing focus can strand keys as pressed, so reset cleanly
	manager:ClearMovementInput()
end)

script.Destroying:Connect(function()
	CharacterRegistry.Unregister(characterEntity)
	manager:Destroy()
	ECS.deleteEntity(characterEntity)
end)
