local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildCatalog = require(ReplicatedStorage.BuildService.BuildCatalog)
local GridMath = require(ReplicatedStorage.BuildService.GridMath)

local GridState = {}
GridState.__index = GridState

function GridState.new(compound: BasePart, cellSize: number)
	local self = setmetatable({}, GridState)
	self.Compound = compound
	self.CellSize = cellSize
	self.Metadata = GridMath.MetadataFromCompound(compound, cellSize)
	self.Occupied = {}
	self.Placements = {}
	return self
end

function GridState:_setCells(placement, value)
	local definition = BuildCatalog:Get(placement.BuildId)
	if not definition then
		return
	end

	for _, cell in GridMath.ResolveCells(placement.GridX, placement.GridY, definition.Footprint.Cells, placement.Rotation) do
		self.Occupied[GridMath.Key(cell.X, cell.Y)] = value
	end
end

function GridState:CanPlace(buildId: string, gridX: number, gridY: number, rotation: number): (boolean, string?)
	local definition = BuildCatalog:Get(buildId)
	if not definition then
		return false, "Unknown build."
	end

	for _, cell in GridMath.ResolveCells(gridX, gridY, definition.Footprint.Cells, rotation) do
		if not GridMath.IsInside(cell.X, cell.Y, self.Metadata.Width, self.Metadata.Height) then
			return false, "Outside compound."
		end

		if self.Occupied[GridMath.Key(cell.X, cell.Y)] then
			return false, "Space is blocked."
		end
	end

	return true
end

function GridState:Add(placement)
	self.Placements[placement.Guid] = placement
	self:_setCells(placement, placement.Guid)
end

function GridState:Remove(guid: string)
	local placement = self.Placements[guid]
	if not placement then
		return nil
	end

	self:_setCells(placement, nil)
	self.Placements[guid] = nil
	return placement
end

function GridState:ExportOccupancy()
	local occupied = {}
	for cellKey, guid in self.Occupied do
		occupied[cellKey] = guid
	end
	return occupied
end

return GridState
