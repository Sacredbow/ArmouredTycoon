--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = script:FindFirstAncestorOfClass("Model")
if not character then
	error("[BaseMovement] Character model ancestor was not found")
end

local Janitor = require(ReplicatedStorage.Packages.janitor)
local ECS = require(ReplicatedStorage.ECS)
local CharacterMovementSystem = require(ReplicatedStorage.CharacterUtilities.CharacterMovementSystem)
local janitor = Janitor.new()

local movement = {
	MovementState = "Idle",
	NextMovementState = nil,
	IsRunning = false,
	IsPerformingAction = false,
	IsGrounded = true,
	JumpHeld = false,
	PressedKeys = {
		W = false,
		A = false,
		S = false,
		D = false,
	},
}

local characterEntity = ECS.createEntity({
	Name = player.Name .. ":Character",
	Model = character,
	Character = character,
	CharacterMovement = movement,
})

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
		janitor:Add(instance.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				movement.IsRunning = true
			end
		end), "Disconnect")

		janitor:Add(instance.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				movement.IsRunning = false
			end
		end), "Disconnect")
	end

	for _, descendant in playerGui:GetDescendants() do
		tryBind(descendant)
		if boundButton then
			return
		end
	end

	local connection = playerGui.DescendantAdded:Connect(function(descendant)
		tryBind(descendant)
		if boundButton then
			connection:Disconnect()
		end
	end)
	janitor:Add(connection, "Disconnect", "SprintButtonWatcher")
end

local function setMoveKeyFromInput(keyCode: Enum.KeyCode, isPressed: boolean)
	local direction = KEY_TO_DIRECTION[keyCode]
	if direction then
		movement.PressedKeys[direction] = isPressed
	end
end

bindSprintButton()

janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	setMoveKeyFromInput(input.KeyCode, true)

	if input.KeyCode == Enum.KeyCode.LeftShift then
		movement.IsRunning = true
	elseif input.KeyCode == Enum.KeyCode.Space then
		movement.JumpHeld = true
	end
end), "Disconnect", "InputBegan")

janitor:Add(UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
	-- Always release held input; UI focus can consume the key-up event.
	setMoveKeyFromInput(input.KeyCode, false)

	if input.KeyCode == Enum.KeyCode.LeftShift then
		movement.IsRunning = false
	elseif input.KeyCode == Enum.KeyCode.Space then
		movement.JumpHeld = false
	end
end), "Disconnect", "InputEnded")

janitor:Add(UserInputService.WindowFocusReleased:Connect(function()
	-- losing focus can strand keys as pressed, so reset the whole snapshot
	for key in movement.PressedKeys do
		movement.PressedKeys[key] = false
	end
	movement.IsRunning = false
	movement.JumpHeld = false
end), "Disconnect", "WindowFocusReleased")

local cleanedUp = false
script.Destroying:Connect(function()
	if cleanedUp then
		return
	end
	cleanedUp = true

	CharacterMovementSystem.Cleanup(characterEntity)
	janitor:Destroy()
	ECS.deleteEntity(characterEntity)
end)
