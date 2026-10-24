local GridMath = require(game:GetService("ReplicatedStorage").BuildService.GridMath)

local GridState = {}

function GridState.create(compound: BasePart, cellSize: number)
	return {
		Compound = compound,
		CellSize = cellSize,
		Metadata = GridMath.MetadataFromCompound(compound, cellSize),
		Occupied = {},
		Placements = {},
	}
end

local function setCells(state, placement, value)
	for _, cell in GridMath.OccupiedCells(placement.BuildId, placement.GridX, placement.GridY, placement.Rotation) do
		state.Occupied[GridMath.Key(cell.X, cell.Y)] = value
	end
end

function GridState.CanPlace(state, buildId: string, gridX: number, gridY: number, rotation: number): (boolean, string?)
	for _, cell in GridMath.OccupiedCells(buildId, gridX, gridY, rotation) do
		if not GridMath.IsInside(cell.X, cell.Y, state.Metadata.Width, state.Metadata.Height) then
			return false, "Placement is outside the build area."
		end
		if state.Occupied[GridMath.Key(cell.X, cell.Y)] then
			return false, "That space is already occupied."
		end
	end
	return true
end

function GridState.Add(state, placement)
	state.Placements[placement.Guid] = placement
	setCells(state, placement, placement.Guid)
end

function GridState.Remove(state, guid: string)
	local placement = state.Placements[guid]
	if not placement then
		return nil
	end
	state.Placements[guid] = nil
	setCells(state, placement, nil)
	return placement
end

function GridState.ExportOccupancy(state)
	local result = {}
	for cellKey, guid in state.Occupied do
		result[cellKey] = guid
	end
	return result
end

return GridState
