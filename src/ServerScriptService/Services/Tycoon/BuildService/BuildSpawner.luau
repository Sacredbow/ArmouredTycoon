local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildCatalog = require(ReplicatedStorage.BuildService.BuildCatalog)
local GridMath = require(ReplicatedStorage.BuildService.GridMath)

local BuildSpawner = {}

function BuildSpawner.create()
	local self = {}
	self.Models = ReplicatedStorage.BuildService:FindFirstChild("BuildModels")
	return self
end

function BuildSpawner:_getContainer(model: Model)
	local container = model:FindFirstChild("PlacedBuilds")
	if container then
		return container
	end

	container = Instance.new("Folder")
	container.Name = "PlacedBuilds"
	container.Parent = model
	return container
end

function BuildSpawner:Spawn(model: Model, placement, compound: BasePart, cellSize: number)
	local tier = BuildCatalog:GetTier(placement.BuildId, placement.Tier)
	if not tier then
		return nil
	end

	local source = self.Models and self.Models:FindFirstChild(tier.ModelName)
	local instance
	if source then
		instance = source:Clone()
	else
		instance = Instance.new("Part")
		instance.Name = placement.BuildId
		instance.Anchored = true
		instance.CanCollide = true
		instance.Size = Vector3.new(cellSize, 5, 1)
		instance.Material = Enum.Material.WoodPlanks
		instance.Color = Color3.fromRGB(109, 75, 47)
	end

	instance.Name = placement.Guid

	local target = GridMath.GridToWorldCFrame(compound, placement.GridX, placement.GridY, placement.Rotation, cellSize)
	if instance:IsA("Model") then
		local _, size = instance:GetBoundingBox()
		instance:PivotTo(target * CFrame.new(0, size.Y / 2, 0))
	elseif instance:IsA("BasePart") then
		instance.CFrame = target * CFrame.new(0, instance.Size.Y / 2, 0)
	end

	instance.Parent = self:_getContainer(model)
	return instance
end

function BuildSpawner:Destroy(model: Model, guid: string)
	local container = model:FindFirstChild("PlacedBuilds")
	local instance = container and container:FindFirstChild(guid)
	if instance then
		instance:Destroy()
	end
end

return BuildSpawner
