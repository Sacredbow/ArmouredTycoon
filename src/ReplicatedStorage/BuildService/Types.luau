local Types = {}

export type TierName = "Bronze" | "Silver" | "Gold" | "Platinum"

export type Footprint = {
	Cells: { Vector2 },
}

export type TierDefinition = {
	Cost: number,
	RefundRate: number,
	Health: number,
	ModelName: string,
}

export type BuildDefinition = {
	Id: string,
	DisplayName: string,
	Category: string,
	Footprint: Footprint,
	Tiers: { [string]: TierDefinition },
}

export type Placement = {
	Guid: string,
	BuildId: string,
	Tier: TierName,
	GridX: number,
	GridY: number,
	Rotation: number,
}

export type GridMetadata = {
	CellSize: number,
	Width: number,
	Height: number,
	Origin: CFrame,
	CompoundSize: Vector3,
}

return Types
