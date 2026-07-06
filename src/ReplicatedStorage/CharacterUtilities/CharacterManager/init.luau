--!strict

-- Made by Sacredbow1

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local MovementBlendController = require(script.Components.MovementBlendController)
local Config = require(script.Config)
local Types = require(script.Types)

local CharacterManager = {}
CharacterManager.__index = CharacterManager

export type MovementType = Types.MovementStateName
export type ActionType = Types.ActionName

type PressedKeys = Types.PressedKeys
type MovementStateName = Types.MovementStateName
type ActionName = Types.ActionName
type MovementDefinition = Types.MovementDefinition
type CharacterManagerData = {
	Character: Model,
	Humanoid: Humanoid,
	Animator: Animator,
	MovementState: MovementStateName,
	NextMovementState: MovementStateName?,
	MovementDefinitions: { [MovementStateName]: MovementDefinition },
	MovementBlendController: MovementBlendController.MovementBlendController,
	IsRunning: boolean,
	IsPerformingAction: boolean,
	IsGrounded: boolean,
	JumpHeld: boolean,
	PressedKeys: PressedKeys,
	DefaultAnimateConnection: RBXScriptConnection?,
	_connections: { RBXScriptConnection },
}

export type CharacterManager = typeof(setmetatable({} :: CharacterManagerData, CharacterManager))

-- grab the animator once and make one if roblox has not inserted it yet
local function getAnimator(humanoid: Humanoid): Animator
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	local newAnimator = Instance.new("Animator")
	newAnimator.Parent = humanoid
	return newAnimator
end

-- movement modules stay tiny, this gathers them into one typed lookup table
local function loadMovementStates(): { [MovementStateName]: MovementDefinition }
	local movementStates = {} :: { [MovementStateName]: MovementDefinition }

	local function loadState(stateName: MovementStateName)
		local module = script.MovementStates:FindFirstChild(stateName)
		assert(module and module:IsA("ModuleScript"), `Missing movement state module: {stateName}`)

		movementStates[stateName] = require(module :: ModuleScript) :: MovementDefinition
	end

	loadState("Idle")
	loadState("Walk")
	loadState("Run")
	loadState("Fall")
	loadState("Climb")

	return movementStates
end

local function getInputMovementMagnitude(keys: PressedKeys): number
	local x = 0
	local z = 0

	if keys.A then
		x -= 1
	end
	if keys.D then
		x += 1
	end
	if keys.W then
		z += 1
	end
	if keys.S then
		z -= 1
	end

	return Vector2.new(x, z).Magnitude
end

local function playerIsBusyWithUi(): boolean
	return GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
end

local function debugAnimation(message: string)
	if Config.Debug and Config.Debug.CharacterAnimations then
		warn(`[CharacterManager] {message}`)
	end
end

local function disableDefaultAnimate(instance: Instance?)
	if not instance or instance.Name ~= "Animate" then
		return
	end

	if instance:IsA("LocalScript") or instance:IsA("Script") then
		debugAnimation(`Disabling default Animate script at {instance:GetFullName()}`)
		instance.Disabled = true
		instance:Destroy()
	end
end

local function stopDefaultMovementTracks(animator: Animator)
	local stoppedCount = 0

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Priority == Enum.AnimationPriority.Core or track.Priority == Enum.AnimationPriority.Idle or track.Priority == Enum.AnimationPriority.Movement then
			track:Stop(0)
			stoppedCount += 1
		end
	end

	if stoppedCount > 0 then
		debugAnimation(`Stopped {stoppedCount} default movement animation track(s)`)
	end
end

function CharacterManager.new(character: Model): CharacterManager
	disableDefaultAnimate(character:FindFirstChild("Animate") :: Instance?)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		error(`[CharacterManager] Humanoid was not found for {character:GetFullName()}`)
	end
	local animator = getAnimator(humanoid)
	stopDefaultMovementTracks(animator)
	debugAnimation(`Creating manager for {character:GetFullName()}`)

	local movementDefinitions = loadMovementStates()
	local movementBlendController = MovementBlendController.new(animator, movementDefinitions, Config.Blend)

	-- keep public fields stable so older scripts can still inspect the manager
	local self = setmetatable({
		Character = character,
		Humanoid = humanoid,
		Animator = animator,
		MovementState = "Idle" :: MovementStateName,
		NextMovementState = nil,
		MovementDefinitions = movementDefinitions,
		MovementBlendController = movementBlendController,
		IsRunning = false,
		IsPerformingAction = false,
		IsGrounded = humanoid.FloorMaterial ~= Enum.Material.Air,
		JumpHeld = false,
		PressedKeys = {
			W = false,
			A = false,
			S = false,
			D = false,
		},
		DefaultAnimateConnection = nil,
		_connections = {},
	}, CharacterManager)

	self:_bindHumanoid()
	self.DefaultAnimateConnection = character.ChildAdded:Connect(disableDefaultAnimate)
	self.MovementBlendController:Start()
	self:ChangeMovementState("Idle")

	return self
end

function CharacterManager:_bindHumanoid()
	-- roblox handles the actual jump, this just gates our action animation
	table.insert(self._connections, self.Humanoid.Jumping:Connect(function(active: boolean)
		if active then
			self:DoAction("Jump")
			self.IsGrounded = false
		end
	end))

	-- landing is when queued movement is allowed to take over again
	table.insert(self._connections, self.Humanoid.StateChanged:Connect(function(_, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
			self.IsGrounded = true
			self:ResumeMovement()
		elseif newState == Enum.HumanoidStateType.Freefall then
			self.IsGrounded = false
			self:ChangeMovementState("Fall")
		elseif newState == Enum.HumanoidStateType.Climbing then
			self.IsGrounded = false
			self:ChangeMovementState("Climb")
		elseif newState == Enum.HumanoidStateType.Jumping then
			self.IsGrounded = false
			self:ChangeMovementState("Fall")
		end
	end))
end

function CharacterManager:SetRunning(isRunning: boolean)
	self.IsRunning = isRunning
end

function CharacterManager:SetJumpHeld(isHeld: boolean)
	self.JumpHeld = isHeld
end

function CharacterManager:SetMoveKey(keyName: "W" | "A" | "S" | "D", isPressed: boolean)
	self.PressedKeys[keyName] = isPressed
end

function CharacterManager:ClearMovementInput()
	-- focus changes can leave keys stuck down, so reset the whole input snapshot
	self.PressedKeys.W = false
	self.PressedKeys.A = false
	self.PressedKeys.S = false
	self.PressedKeys.D = false
	self.IsRunning = false
	self.JumpHeld = false
	self:Update()
end

function CharacterManager:GetDesiredMovementState(): MovementStateName
	if playerIsBusyWithUi() then
		return "Idle"
	end

	local humanoidState = self.Humanoid:GetState()
	if humanoidState == Enum.HumanoidStateType.Climbing then
		return "Climb"
	elseif humanoidState == Enum.HumanoidStateType.Freefall or humanoidState == Enum.HumanoidStateType.Jumping then
		return "Fall"
	end

	local movingByHumanoid = self.Humanoid.MoveDirection.Magnitude > Config.Movement.MoveThreshold
	local movingByInput = getInputMovementMagnitude(self.PressedKeys) > Config.Movement.MoveThreshold
	local isMoving = movingByHumanoid or movingByInput

	if not isMoving then
		return "Idle"
	end

	if self.IsRunning or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		return "Run"
	end

	return "Walk"
end

function CharacterManager:ChangeMovementState(state: MovementStateName)
	-- do not restart the same target, the blend controller is already easing there
	if self.MovementState == state then
		return
	end

	-- if an action is playing, remember where movement wanted to go next
	if self.IsPerformingAction then
		self.NextMovementState = state
		return
	end

	local definition = self.MovementDefinitions[state]
	if not definition then
		debugAnimation(`Missing movement definition for state "{state}"`)
		return
	end

	self.MovementState = state
	self.Humanoid.WalkSpeed = definition.WalkSpeed
	self.MovementBlendController:SetTargetState(state)
	debugAnimation(`Movement state -> {state}; WalkSpeed={definition.WalkSpeed}; Animation={definition.AnimationId}`)
end

function CharacterManager:Update(deltaTime: number?)
	local dt = deltaTime or 1 / 60
	local desiredState = self:GetDesiredMovementState()

	if self.IsPerformingAction then
		self.NextMovementState = desiredState
	else
		self:ChangeMovementState(desiredState)
	end

	self.MovementBlendController:Update(dt)
end

function CharacterManager:PlayActionAnimation(animationId: string, priority: Enum.AnimationPriority?): AnimationTrack
	-- actions are one-shot tracks layered above the movement blend
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local track = self.Animator:LoadAnimation(animation)
	animation:Destroy()

	track.Looped = false
	track.Priority = priority or Enum.AnimationPriority.Action
	track:Play(Config.Actions.FadeTime)
	debugAnimation(`Action animation -> {animationId}; Priority={track.Priority.Name}`)

	track.Stopped:Once(function()
		debugAnimation(`Action animation stopped -> {animationId}`)
		track:Destroy()
		self:ResumeMovement()
	end)

	return track
end

function CharacterManager:DoAction(action: ActionName)
	-- only one action at a time for now, keeps the state machine predictable
	if self.IsPerformingAction then
		debugAnimation(`Action "{action}" ignored because another action is already playing`)
		return
	end

	if action == "Jump" and not self.IsGrounded then
		debugAnimation("Jump action ignored because character is not grounded")
		return
	end

	local module = script.Actions:FindFirstChild(action)
	if not module or not module:IsA("ModuleScript") then
		debugAnimation(`Missing action module for "{action}"`)
		return
	end

	self.IsPerformingAction = true
	require(module :: ModuleScript).Do(self)
end

function CharacterManager:ResumeMovement()
	self.IsPerformingAction = false

	-- queued movement wins first, otherwise ask input for the freshest state
	local pendingState = self.NextMovementState
	self.NextMovementState = nil

	if pendingState then
		self:ChangeMovementState(pendingState)
	else
		self:ChangeMovementState(self:GetDesiredMovementState())
	end
end

function CharacterManager:Destroy()
	-- this matters when characters respawn or the script gets reloaded
	debugAnimation(`Destroying manager for {self.Character:GetFullName()}`)
	if self.DefaultAnimateConnection then
		self.DefaultAnimateConnection:Disconnect()
		self.DefaultAnimateConnection = nil
	end

	for _, connection in self._connections do
		connection:Disconnect()
	end

	table.clear(self._connections)
	self.MovementBlendController:Destroy()
end

return CharacterManager
