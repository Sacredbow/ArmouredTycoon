--!strict

-- shared names live here so strict mode catches typo states fast
export type MovementStateName = "Idle" | "Walk" | "Run" | "Fall" | "Climb"
export type ActionName = "Jump"

-- the client script owns these booleans, the manager just reads the snapshot
export type PressedKeys = {
	W: boolean,
	A: boolean,
	S: boolean,
	D: boolean,
}

-- movement modules return this small shape, nothing runs from those files
export type MovementDefinition = {
	Name: MovementStateName,
	AnimationId: string,
	WalkSpeed: number,
	BlendPosition: number,
}

-- blend tuning stays grouped so animation feel can be adjusted in one spot
export type BlendConfig = {
	Response: number,
	FadeTime: number,
	MinimumWeight: number,
}

return {}
