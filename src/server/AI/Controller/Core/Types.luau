--!strict

export type GoalDirection = "ToGoal" | "ToStart"
export type StateName = "Patrol" | "ObservePlayer" | "AvoidFrontBlock" | "Idle" | "Dead"
export type Disposition = "Happy" | "Normal" | "Abrasive"
export type AvoidMode = "Sidestep" | "Backpedal"

export type Config = {
	UpdateInterval: number,
	RespawnDelay: number,
	DefaultWalkSpeed: number,
	MoveTimeout: number,
	PathRetryDelay: number,
	CloseWaypointDistance: number,
	WaypointMinSegmentDistance: number,
	WaypointTurnDotThreshold: number,
	ObservationRadius: number,
	ObservationMaxTargets: number,
	ObservationFrontDot: number,
	ObservationCooldown: number,
	ObservationDuration: number,
	ObservationIgnoreDuration: number,
	RepeatInteractionWindow: number,
	AbrasiveRecoveryDuration: number,
	DamageSpeechCooldown: number,
	LookStep: number,
	AvoidTriggerDistance: number,
	AvoidFrontDot: number,
	AvoidStepDistance: number,
	AvoidDuration: number,
	AvoidRaycastDistance: number,
	AvoidRaycastHeight: number,
	AvoidClearanceTieThreshold: number,
	DebugAvoidanceRays: boolean,
	DebugObservation: boolean,
	DebugRayLifetime: number,
	DebugRayThickness: number,
	IdleMinDuration: number,
	IdleMaxDuration: number,
	SeparationRadius: number,
	SeparationStrength: number,
	Path: {
		AgentCanJump: boolean,
		AgentCanClimb: boolean,
		AgentHeight: number,
		AgentRadius: number,
		WaypointSpacing: number,
		Costs: {
			[string]: number,
		},
	},
}

export type AIContext = {
	NPC: Model,
	Humanoid: Humanoid,
	Name: string,
	PrimaryPart: BasePart,
	StartPivot: CFrame,
	Goal: StringValue?,
	Path: Path,
	DiedConnection: RBXScriptConnection?,
	HealthConnection: RBXScriptConnection?,
	StateThreadRunning: boolean,
	LastHealth: number,
	LastObservationTime: number,
	LastDamageSpeechTime: number,
	IdleUntil: number,
	AvoidUntil: number,
	AvoidPauseUntil: number,
	AbrasiveUntil: number,
	IgnoreObservationUntil: number,
	AvoidDirection: number,
	GoalDirection: GoalDirection,
	Disposition: Disposition,
	LastInteractionUserId: number,
	LastInteractionTime: number,
	RepeatInteractionCount: number,
	LastSpokenLine: string,
	ObservationTarget: BasePart?,
	ObservationSecondaryTarget: BasePart?,
	ObservationLine: string?,
	ObservationLookPosition: Vector3?,
	ObservationHoldDuration: number,
	ObservationShouldWave: boolean,
	ObservationShouldAvoidAfter: boolean,
	ObservationAvoidMode: AvoidMode,
	AvoidLookTarget: BasePart?,
	AvoidTarget: BasePart?,
	AvoidMode: AvoidMode,
	Config: Config,
}

export type StateMachineLike = {
	SetState: (self: StateMachineLike, stateName: StateName) -> (),
	GetStateName: (self: StateMachineLike) -> StateName?,
}

export type State = {
	Name: StateName,
	Enter: ((context: AIContext, machine: StateMachineLike) -> ())?,
	Update: (context: AIContext, machine: StateMachineLike) -> (),
	Exit: ((context: AIContext, machine: StateMachineLike) -> ())?,
}

local Types = {}

return Types
