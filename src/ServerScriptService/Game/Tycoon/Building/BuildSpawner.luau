local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildCatalog = require(ReplicatedStorage.Shared.Game.Tycoon.Building.BuildCatalog)
local GridMath = require(ReplicatedStorage.Shared.Game.Tycoon.Building.GridMath)

local BuildSpawner = {}
local BuildModels = ReplicatedStorage.Shared.Game.Tycoon.Building:FindFirstChild("BuildModels")

local function GetContainer(Model: Model): Folder
	local Container = Model:FindFirstChild("PlacedBuilds")
	if Container and Container:IsA("Folder") then
		return Container
	end

	Container = Instance.new("Folder")
	Container.Name = "PlacedBuilds"
	Container.Parent = Model
	return Container
end

function BuildSpawner.Spawn(Model: Model, Placement, Compound: BasePart, CellSize: number)
	local Tier = BuildCatalog:GetTier(Placement.BuildId, Placement.Tier)
	if not Tier then
		return nil
	end

	local Source = BuildModels and BuildModels:FindFirstChild(Tier.ModelName)
	local Instance
	if Source then
		Instance = Source:Clone()
	else
		Instance = Instance.new("Part")
		Instance.Name = Placement.BuildId
		Instance.Anchored = true
		Instance.CanCollide = true
		Instance.Size = Vector3.new(CellSize, 5, 1)
		Instance.Material = Enum.Material.WoodPlanks
		Instance.Color = Color3.fromRGB(109, 75, 47)
	end

	Instance.Name = Placement.Guid

	local Target = GridMath.GridToWorldCFrame(Compound, Placement.GridX, Placement.GridY, Placement.Rotation, CellSize)
	if Instance:IsA("Model") then
		local _, Size = Instance:GetBoundingBox()
		Instance:PivotTo(Target * CFrame.new(0, Size.Y / 2, 0))
	elseif Instance:IsA("BasePart") then
		Instance.CFrame = Target * CFrame.new(0, Instance.Size.Y / 2, 0)
	end

	Instance.Parent = GetContainer(Model)
	return Instance
end

function BuildSpawner.Destroy(Model: Model, Guid: string)
	local Container = Model:FindFirstChild("PlacedBuilds")
	local Instance = Container and Container:FindFirstChild(Guid)
	if Instance then
		Instance:Destroy()
	end
end

return BuildSpawner
