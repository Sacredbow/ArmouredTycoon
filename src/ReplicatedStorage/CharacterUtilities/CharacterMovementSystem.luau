--!strict

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.CharacterUtilities.CharacterManager.Config)

type MovementState = "Idle" | "Walk" | "Run" | "Fall" | "Climb"
type MovementData = {
	MovementState: MovementState,
	NextMovementState: MovementState?,
	IsRunning: boolean,
	IsPerformingAction: boolean,
	IsGrounded: boolean,
	JumpHeld: boolean,
	PressedKeys: { [string]: boolean },
}

type TrackState = {
	Track: AnimationTrack,
	Weight: number,
	TargetWeight: number,
}

type CharacterResources = {
	Humanoid: Humanoid,
	Animator: Animator,
	Tracks: { [MovementState]: TrackState },
	Connections: { RBXScriptConnection },
	ActionTrack: AnimationTrack?,
	BlendValue: number,
	TargetBlendValue: number,
	MovementWeight: number,
	TargetMovementWeight: number,
	TargetState: MovementState,
	BaseWalkSpeed: number,
}

local Resources: { [number]: CharacterResources } = {}
local StateModules = ReplicatedStorage.CharacterUtilities.CharacterManager.MovementStates

local function loadDefinition(state: MovementState)
	local module = StateModules:FindFirstChild(state)
	assert(module and module:IsA("ModuleScript"), "Missing movement state module: " .. state)
	return require(module)
end

local function getAnimator(humanoid: Humanoid): Animator
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	local created = Instance.new("Animator")
	created.Parent = humanoid
	return created
end

local function stopDefaultAnimate(character: Model)
	local animate = character:FindFirstChild("Animate")
	if animate and (animate:IsA("LocalScript") or animate:IsA("Script")) then
		animate:Destroy()
	end
end

local function playerBusyWithUi(): boolean
	return GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil
end

local function movementMagnitude(pressedKeys: { [string]: boolean }): number
	local x = 0
	local z = 0
	if pressedKeys.A then x -= 1 end
	if pressedKeys.D then x += 1 end
	if pressedKeys.W then z += 1 end
	if pressedKeys.S then z -= 1 end
	return Vector2.new(x, z).Magnitude
end

local function ease(current: number, target: number, response: number, deltaTime: number): number
	return current + (target - current) * (1 - math.exp(-response * deltaTime))
end

local function setTargetState(data: MovementData, resources: CharacterResources, state: MovementState)
	data.MovementState = state
	resources.TargetState = state
	if state == "Idle" then
		resources.TargetMovementWeight = 0
		resources.TargetBlendValue = 0
	elseif state == "Walk" then
		resources.TargetMovementWeight = 1
		resources.TargetBlendValue = 0
	elseif state == "Run" then
		resources.TargetMovementWeight = 1
		resources.TargetBlendValue = 1
	else
		resources.TargetMovementWeight = 1
		resources.TargetBlendValue = if state == "Fall" then 0.25 else 0.75
	end

	local definition = loadDefinition(state)
	resources.BaseWalkSpeed = definition.WalkSpeed
end

local function applyWalkSpeed(resources: CharacterResources)
	local override = resources.Humanoid:GetAttribute("CombatWalkSpeed")
	if typeof(override) == "number" and override == override and override ~= math.huge and override ~= -math.huge and override >= 0 then
		resources.Humanoid.WalkSpeed = override
	else
		resources.Humanoid.WalkSpeed = resources.BaseWalkSpeed
	end
end

local function desiredState(data: MovementData, resources: CharacterResources): MovementState
	if playerBusyWithUi() then
		return "Idle"
	end

	local humanoidState = resources.Humanoid:GetState()
	if humanoidState == Enum.HumanoidStateType.Climbing then
		return "Climb"
	elseif humanoidState == Enum.HumanoidStateType.Freefall or humanoidState == Enum.HumanoidStateType.Jumping then
		return "Fall"
	end

	local moving = resources.Humanoid.MoveDirection.Magnitude > Config.Movement.MoveThreshold
		or movementMagnitude(data.PressedKeys) > Config.Movement.MoveThreshold
	if not moving then
		return "Idle"
	end

	return if data.IsRunning or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then "Run" else "Walk"
end

local function updateTracks(resources: CharacterResources, deltaTime: number)
	resources.BlendValue = ease(resources.BlendValue, resources.TargetBlendValue, Config.Blend.Response, deltaTime)
	resources.MovementWeight = ease(resources.MovementWeight, resources.TargetMovementWeight, Config.Blend.Response, deltaTime)

	local idleWeight = 1 - resources.MovementWeight
	local walkWeight = resources.MovementWeight * (1 - resources.BlendValue)
	local runWeight = resources.MovementWeight * resources.BlendValue
	local fallWeight = if resources.TargetState == "Fall" then resources.MovementWeight else 0
	local climbWeight = if resources.TargetState == "Climb" then resources.MovementWeight else 0

	if resources.TargetState == "Fall" or resources.TargetState == "Climb" then
		idleWeight = 0
		walkWeight = 0
		runWeight = 0
	end

	for state, trackState in resources.Tracks do
		local wanted = if state == "Idle" then idleWeight
			elseif state == "Walk" then walkWeight
			elseif state == "Run" then runWeight
			elseif state == "Fall" then fallWeight
			else climbWeight
		local target = math.max(wanted, Config.Blend.MinimumWeight)
		trackState.TargetWeight = target
		trackState.Weight = ease(trackState.Weight, target, Config.Blend.Response, deltaTime)
		trackState.Track:AdjustWeight(trackState.Weight, Config.Blend.FadeTime)
	end
end

local function playJump(data: MovementData, resources: CharacterResources)
	if data.IsPerformingAction or not data.IsGrounded then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = Config.Animations.Jump
	local ok, result = pcall(function()
		return resources.Animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		warn("[CharacterMovementSystem] Failed to load jump animation: " .. tostring(result))
		return
	end

	local track = result :: AnimationTrack
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	data.IsPerformingAction = true
	resources.ActionTrack = track
	track:Play(Config.Actions.FadeTime)
	local connection = track.Stopped:Connect(function()
		if resources.ActionTrack == track then
			resources.ActionTrack = nil
			data.IsPerformingAction = false
			data.NextMovementState = nil
		end
		track:Destroy()
	end)
	table.insert(resources.Connections, connection)
end

local function initialize(entity: number, character: Model, data: MovementData): CharacterResources?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	stopDefaultAnimate(character)
	local animator = getAnimator(humanoid)
	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Priority == Enum.AnimationPriority.Core or track.Priority == Enum.AnimationPriority.Idle or track.Priority == Enum.AnimationPriority.Movement then
			track:Stop(0)
		end
	end

	local resources: CharacterResources = {
		Humanoid = humanoid,
		Animator = animator,
		Tracks = {},
		Connections = {},
		ActionTrack = nil,
		BlendValue = 0,
		TargetBlendValue = 0,
		MovementWeight = 0,
		TargetMovementWeight = 0,
		TargetState = "Idle",
		BaseWalkSpeed = Config.Speeds.Idle,
	}

	for _, state: MovementState in { "Idle", "Walk", "Run", "Fall", "Climb" } do
		local definition = loadDefinition(state)
		local animation = Instance.new("Animation")
		animation.AnimationId = definition.AnimationId
		local ok, result = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		animation:Destroy()
		if not ok then
			warn("[CharacterMovementSystem] Failed to load movement animation: " .. tostring(result))
			continue
		end

		local track = result :: AnimationTrack
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Movement
		track:Play(0, Config.Blend.MinimumWeight, 1)
		track:AdjustWeight(Config.Blend.MinimumWeight, 0)
		resources.Tracks[state] = {
			Track = track,
			Weight = Config.Blend.MinimumWeight,
			TargetWeight = Config.Blend.MinimumWeight,
		}
	end

	Resources[entity] = resources
	setTargetState(data, resources, "Idle")

	table.insert(resources.Connections, humanoid.Jumping:Connect(function(active)
		if active then
			data.IsGrounded = false
			playJump(data, resources)
		end
	end))
	table.insert(resources.Connections, humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
			data.IsGrounded = true
		elseif newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping then
			data.IsGrounded = false
		end
	end))

	return resources
end

local function cleanup(entity: number)
	local resources = Resources[entity]
	if not resources then
		return
	end

	for _, connection in resources.Connections do
		connection:Disconnect()
	end
	for _, trackState in resources.Tracks do
		trackState.Track:Stop(Config.Blend.FadeTime)
		trackState.Track:Destroy()
	end
	if resources.ActionTrack then
		resources.ActionTrack:Stop(0)
		resources.ActionTrack:Destroy()
	end
	table.clear(resources.Connections)
	table.clear(resources.Tracks)
	Resources[entity] = nil
end

local System = {}

function System.Cleanup(entity: number)
	cleanup(entity)
end

function System.Run(context)
	local world = context.world
	local Components = context.Components
	local deltaTime = context.dt

	for entity, character in world:query(Components.Character) do
		local data = world:get(entity, Components.CharacterMovement) :: MovementData
		if not character or not character.Parent or not data then
			cleanup(entity)
			world:delete(entity)
			continue
		end

		local resources = Resources[entity]
		if not resources then
			resources = initialize(entity, character, data)
		end
		if not resources then
			cleanup(entity)
			world:delete(entity)
			continue
		end

		local nextState = desiredState(data, resources)
		if data.IsPerformingAction then
			data.NextMovementState = nextState
		else
			if data.MovementState ~= nextState then
				setTargetState(data, resources, nextState)
			end
			data.NextMovementState = nil
		end
		applyWalkSpeed(resources)
		updateTracks(resources, deltaTime)
	end
end
return System
