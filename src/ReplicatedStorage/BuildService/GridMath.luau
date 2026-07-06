local GridMath = {}

local function key(gridX: number, gridY: number): string
	return `{gridX}:{gridY}`
end

function GridMath.Key(gridX: number, gridY: number): string
	return key(gridX, gridY)
end

function GridMath.RoundRotation(rotation: number): number
	return (math.round(rotation / 90) * 90) % 360
end

function GridMath.RotateCell(cell: Vector2, rotation: number): Vector2
	local rounded = GridMath.RoundRotation(rotation)
	if rounded == 90 then
		return Vector2.new(-cell.Y, cell.X)
	elseif rounded == 180 then
		return Vector2.new(-cell.X, -cell.Y)
	elseif rounded == 270 then
		return Vector2.new(cell.Y, -cell.X)
	end

	return cell
end

function GridMath.ResolveCells(originX: number, originY: number, cells: { Vector2 }, rotation: number): { Vector2 }
	local resolved = {}
	for _, cell in cells do
		local rotated = GridMath.RotateCell(cell, rotation)
		table.insert(resolved, Vector2.new(originX + rotated.X, originY + rotated.Y))
	end

	return resolved
end

function GridMath.IsInside(gridX: number, gridY: number, width: number, height: number): boolean
	local halfWidth = math.floor(width / 2)
	local halfHeight = math.floor(height / 2)

	return gridX >= -halfWidth
		and gridX < width - halfWidth
		and gridY >= -halfHeight
		and gridY < height - halfHeight
end

function GridMath.WorldToGrid(compound: BasePart, worldPosition: Vector3, cellSize: number): (number, number)
	local localPosition = compound.CFrame:PointToObjectSpace(worldPosition)
	local gridX = math.floor((localPosition.X / cellSize) + 0.5)
	local gridY = math.floor((localPosition.Z / cellSize) + 0.5)
	return gridX, gridY
end

function GridMath.WorldToGridFromMetadata(metadata, worldPosition: Vector3): (number, number)
	local localPosition = metadata.Origin:PointToObjectSpace(worldPosition)
	local gridX = math.floor((localPosition.X / metadata.CellSize) + 0.5)
	local gridY = math.floor((localPosition.Z / metadata.CellSize) + 0.5)
	return gridX, gridY
end

function GridMath.GridToWorldCFrame(compound: BasePart, gridX: number, gridY: number, rotation: number, cellSize: number): CFrame
	local localX = gridX * cellSize
	local localZ = gridY * cellSize
	local topY = compound.Size.Y / 2
	return compound.CFrame * CFrame.new(localX, topY, localZ) * CFrame.Angles(0, math.rad(GridMath.RoundRotation(rotation)), 0)
end

function GridMath.GridToWorldCFrameFromMetadata(metadata, gridX: number, gridY: number, rotation: number): CFrame
	local localX = gridX * metadata.CellSize
	local localZ = gridY * metadata.CellSize
	local topY = metadata.CompoundSize.Y / 2
	return metadata.Origin * CFrame.new(localX, topY, localZ) * CFrame.Angles(0, math.rad(GridMath.RoundRotation(rotation)), 0)
end

function GridMath.MetadataFromCompound(compound: BasePart, cellSize: number)
	return {
		CellSize = cellSize,
		Width = math.max(1, math.floor(compound.Size.X / cellSize)),
		Height = math.max(1, math.floor(compound.Size.Z / cellSize)),
		Origin = compound.CFrame,
		CompoundSize = compound.Size,
	}
end

return GridMath
