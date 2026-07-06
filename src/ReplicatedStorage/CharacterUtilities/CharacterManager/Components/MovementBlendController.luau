--!strict

local Types = require(script.Parent.Parent.Types)
local ConfigModule = require(script.Parent.Parent.Config)

type BlendConfig = Types.BlendConfig
type MovementDefinition = Types.MovementDefinition
type MovementStateName = Types.MovementStateName

local MovementBlendController = {}
MovementBlendController.__index = MovementBlendController

type TrackState = {
	Track: AnimationTrack,
	Weight: number,
	TargetWeight: number,
	BlendPosition: number,
}

type MovementBlendControllerData = {
	Animator: Animator,
	Config: BlendConfig,
	Tracks: { [MovementStateName]: TrackState },
	BlendValue: number,
	TargetBlendValue: number,
	MovementWeight: number,
	TargetMovementWeight: number,
	TargetState: MovementStateName,
}

export type MovementBlendController = typeof(setmetatable({} :: MovementBlendControllerData, MovementBlendController))

local function debugAnimation(message: string)
	if ConfigModule.Debug and ConfigModule.Debug.CharacterAnimations then
		warn(`[MovementBlendController] {message}`)
	end
end

-- each movement animation stays loaded so blending is just weight changes
local function loadTrack(animator: Animator, definition: MovementDefinition): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = definition.AnimationId

	local success, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if not success then
		error(`[MovementBlendController] Failed to load {definition.Name} animation {definition.AnimationId}: {trackOrError}`)
	end

	local track = trackOrError :: AnimationTrack
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	debugAnimation(`Loaded {definition.Name} movement animation {definition.AnimationId}`)

	return track
end

-- tiny spring-like easing without needing a real spring object
local function easeNumber(current: number, target: number, response: number, deltaTime: number): number
	local alpha = 1 - math.exp(-response * deltaTime)
	return current + (target - current) * alpha
end

local function clampUnit(value: number): number
	return math.clamp(value, 0, 1)
end

function MovementBlendController.new(
	animator: Animator,
	definitions: { [MovementStateName]: MovementDefinition },
	config: BlendConfig
): MovementBlendController
	local tracks = {} :: { [MovementStateName]: TrackState }

	-- using literal calls here keeps luau from widening the state names to string
	local function addMovementTrack(stateName: MovementStateName)
		local definition = definitions[stateName]
		assert(definition, `Missing movement definition: {stateName}`)

		tracks[stateName] = {
			Track = loadTrack(animator, definition),
			Weight = 0,
			TargetWeight = 0,
			BlendPosition = definition.BlendPosition,
		}
	end

	addMovementTrack("Idle")
	addMovementTrack("Walk")
	addMovementTrack("Run")
	addMovementTrack("Fall")
	addMovementTrack("Climb")

	return setmetatable({
		Animator = animator,
		Config = config,
		Tracks = tracks,
		BlendValue = 0,
		TargetBlendValue = 0,
		MovementWeight = 0,
		TargetMovementWeight = 0,
		TargetState = "Idle" :: MovementStateName,
	}, MovementBlendController)
end

function MovementBlendController:Start()
	-- all movement tracks play quietly from the start, then weights do the work
	for _, state in self.Tracks do
		state.Track:Play(0, self.Config.MinimumWeight, 1)
		state.Track:AdjustWeight(self.Config.MinimumWeight, 0)
	end

	self:SetTargetState("Idle")
	self:Update(1)
	debugAnimation("Started movement blend tracks")
end

function MovementBlendController:SetTargetState(stateName: MovementStateName)
	self.TargetState = stateName

	-- idle has no movement weight, walk/run share a 1d blend value
	if stateName == "Idle" then
		self.TargetMovementWeight = 0
		self.TargetBlendValue = 0
	elseif stateName == "Walk" then
		self.TargetMovementWeight = 1
		self.TargetBlendValue = 0
	elseif stateName == "Run" then
		self.TargetMovementWeight = 1
		self.TargetBlendValue = 1
	elseif stateName == "Fall" or stateName == "Climb" then
		self.TargetMovementWeight = 1
		self.TargetBlendValue = if stateName == "Fall" then 0.25 else 0.75
	end

	debugAnimation(`Target state -> {stateName}`)
end

function MovementBlendController:SetTargetBlend(blendValue: number, movementWeight: number?)
	-- this lets future systems drive the blend directly if they need to
	self.TargetBlendValue = clampUnit(blendValue)
	self.TargetMovementWeight = clampUnit(movementWeight or 1)
end

function MovementBlendController:Update(deltaTime: number)
	self.BlendValue = easeNumber(self.BlendValue, self.TargetBlendValue, self.Config.Response, deltaTime)
	self.MovementWeight = easeNumber(self.MovementWeight, self.TargetMovementWeight, self.Config.Response, deltaTime)

	-- first blend idle versus moving, then split moving between walk and run
	local idleWeight = 1 - self.MovementWeight
	local walkWeight = self.MovementWeight * (1 - self.BlendValue)
	local runWeight = self.MovementWeight * self.BlendValue
	local fallWeight = if self.TargetState == "Fall" then self.MovementWeight else 0
	local climbWeight = if self.TargetState == "Climb" then self.MovementWeight else 0

	if self.TargetState == "Fall" or self.TargetState == "Climb" then
		idleWeight = 0
		walkWeight = 0
		runWeight = 0
	end

	for stateName, state in self.Tracks do
		local wantedWeight = 0

		if stateName == "Idle" then
			wantedWeight = idleWeight
		elseif stateName == "Walk" then
			wantedWeight = walkWeight
		elseif stateName == "Run" then
			wantedWeight = runWeight
		elseif stateName == "Fall" then
			wantedWeight = fallWeight
		elseif stateName == "Climb" then
			wantedWeight = climbWeight
		end

		local targetWeight = math.max(wantedWeight, self.Config.MinimumWeight)
		state.TargetWeight = targetWeight
		state.Weight = easeNumber(state.Weight, targetWeight, self.Config.Response, deltaTime)
		state.Track:AdjustWeight(state.Weight, self.Config.FadeTime)
	end
end

function MovementBlendController:Destroy()
	-- stop and destroy everything we loaded when the manager goes away
	for _, state in self.Tracks do
		state.Track:Stop(self.Config.FadeTime)
		state.Track:Destroy()
	end

	table.clear(self.Tracks)
end

return MovementBlendController
