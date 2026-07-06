local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BuildCatalog = require(ReplicatedStorage.BuildService.BuildCatalog)
local GridMath = require(ReplicatedStorage.BuildService.GridMath)

local BuildServiceClient = {}
BuildServiceClient.__index = BuildServiceClient

function BuildServiceClient.new()
	local self = setmetatable({}, BuildServiceClient)
	self.Player = Players.LocalPlayer
	self.Mouse = self.Player:GetMouse()
	self.Remote = nil
	self.Active = false
	self.SelectedBuild = "Wood"
	self.SelectedTier = BuildCatalog.DefaultTier
	self.Rotation = 0
	self.GridState = nil
	self.Preview = nil
	self.GridFolder = nil
	self.Connections = {}
	self.CharacterConnections = {}
	self.ModeConnections = {}
	return self
end

function BuildServiceClient:Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	self.Remote = remotes and remotes:FindFirstChild("BuildAction")
	if not self.Remote or not self.Remote:IsA("RemoteFunction") then
		warn("[BuildServiceClient] BuildAction remote is unavailable.")
		return
	end

	self:_bindCharacter(self.Player.Character)
	table.insert(self.Connections, self.Player.CharacterAdded:Connect(function(character)
		self:_bindCharacter(character)
	end))
end

function BuildServiceClient:_bindCharacter(character)
	if not character then
		return
	end

	for _, connection in self.CharacterConnections do
		connection:Disconnect()
	end
	table.clear(self.CharacterConnections)

	table.insert(self.CharacterConnections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and self:_isBuilder(child) then
			self:Enter()
		end
	end))

	table.insert(self.CharacterConnections, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and self:_isBuilder(child) then
			self:Exit()
		end
	end))

	for _, child in character:GetChildren() do
		if child:IsA("Tool") and self:_isBuilder(child) then
			self:Enter()
			return
		end
	end
end

function BuildServiceClient:_isBuilder(tool: Tool): boolean
	return tool:GetAttribute("ToolType") == "Builder" or tool.Name == "Builder"
end

function BuildServiceClient:Enter()
	if self.Active then
		return
	end

	local ok, result = self.Remote:InvokeServer("GetState")
	if not ok then
		warn(`[BuildServiceClient] {result}`)
		return
	end

	self.GridState = result
	self.Active = true
	self:_createGrid()
	self:_createPreview()
	self:_bindBuildInputs()
end

function BuildServiceClient:Exit()
	self.Active = false
	self.GridState = nil

	for _, connection in self.ModeConnections do
		connection:Disconnect()
	end
	table.clear(self.ModeConnections)

	if self.Preview then
		self.Preview:Destroy()
		self.Preview = nil
	end

	if self.GridFolder then
		self.GridFolder:Destroy()
		self.GridFolder = nil
	end
end

function BuildServiceClient:_createGrid()
	if self.GridFolder then
		self.GridFolder:Destroy()
	end

	local metadata = self.GridState.Metadata
	local folder = Instance.new("Folder")
	folder.Name = "BuildServicePreview"
	folder.Parent = workspace
	self.GridFolder = folder

	local compound = Instance.new("Part")
	compound.Name = "BuildArea"
	compound.Anchored = true
	compound.CanCollide = false
	compound.CanQuery = false
	compound.Transparency = 0.72
	compound.Material = Enum.Material.Neon
	compound.Color = Color3.fromRGB(45, 126, 255)
	compound.Size = Vector3.new(metadata.CompoundSize.X, 0.08, metadata.CompoundSize.Z)
	compound.CFrame = metadata.Origin * CFrame.new(0, metadata.CompoundSize.Y / 2 + 0.05, 0)
	compound.Parent = folder
end

function BuildServiceClient:_createPreview()
	local models = ReplicatedStorage.BuildService:FindFirstChild("BuildModels")
	local source = models and models:FindFirstChild("Wood")
	local preview
	if source then
		preview = source:Clone()
	else
		preview = Instance.new("Part")
		preview.Name = "WoodPreview"
		preview.Size = Vector3.new(4, 5, 1)
	end

	preview.Name = "BuildPreview"
	if preview:IsA("BasePart") then
		preview.Anchored = true
		preview.CanCollide = false
		preview.CanQuery = false
		preview.Transparency = 0.35
		preview.Material = Enum.Material.Neon
	elseif preview:IsA("Model") then
		for _, descendant in preview:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.Transparency = 0.35
				descendant.Material = Enum.Material.Neon
			end
		end
	end

	preview.Parent = workspace
	self.Preview = preview
end

function BuildServiceClient:_bindBuildInputs()
	table.insert(self.ModeConnections, RunService.RenderStepped:Connect(function()
		self:_updatePreview()
	end))

	table.insert(self.ModeConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not self.Active then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_placePreview()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_removeHovered()
		elseif input.KeyCode == Enum.KeyCode.R then
			self.Rotation = (self.Rotation + 90) % 360
		end
	end))
end

function BuildServiceClient:_currentGrid()
	local metadata = self.GridState and self.GridState.Metadata
	if not metadata then
		return nil
	end

	local gridX, gridY = GridMath.WorldToGridFromMetadata(metadata, self.Mouse.Hit.Position)
	return gridX, gridY
end

function BuildServiceClient:_previewValid(gridX: number, gridY: number): boolean
	local metadata = self.GridState.Metadata
	local definition = BuildCatalog:Get(self.SelectedBuild)
	if not definition then
		return false
	end

	for _, cell in GridMath.ResolveCells(gridX, gridY, definition.Footprint.Cells, self.Rotation) do
		if not GridMath.IsInside(cell.X, cell.Y, metadata.Width, metadata.Height) then
			return false
		end

		if self.GridState.Occupied[GridMath.Key(cell.X, cell.Y)] then
			return false
		end
	end

	return true
end

function BuildServiceClient:_setPreviewColor(valid: boolean)
	local color = if valid then Color3.fromRGB(36, 118, 255) else Color3.fromRGB(255, 56, 74)
	if self.Preview:IsA("BasePart") then
		self.Preview.Color = color
	elseif self.Preview:IsA("Model") then
		for _, descendant in self.Preview:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = color
			end
		end
	end
end

function BuildServiceClient:_updatePreview()
	if not self.Active or not self.Preview or not self.GridState then
		return
	end

	local gridX, gridY = self:_currentGrid()
	if not gridX or not gridY then
		return
	end

	local metadata = self.GridState.Metadata
	local target = GridMath.GridToWorldCFrameFromMetadata(metadata, gridX, gridY, self.Rotation)

	local valid = self:_previewValid(gridX, gridY)
	self:_setPreviewColor(valid)

	if self.Preview:IsA("BasePart") then
		self.Preview.CFrame = target * CFrame.new(0, self.Preview.Size.Y / 2, 0)
	elseif self.Preview:IsA("Model") then
		local _, size = self.Preview:GetBoundingBox()
		self.Preview:PivotTo(target * CFrame.new(0, size.Y / 2, 0))
	end
end

function BuildServiceClient:_placePreview()
	local gridX, gridY = self:_currentGrid()
	if not gridX or not gridY or not self:_previewValid(gridX, gridY) then
		return
	end

	local ok, result = self.Remote:InvokeServer("Place", {
		BuildId = self.SelectedBuild,
		Tier = self.SelectedTier,
		GridX = gridX,
		GridY = gridY,
		Rotation = self.Rotation,
	})

	if ok and type(result) == "table" then
		self.GridState.Occupied = result.Occupied or self.GridState.Occupied
	elseif not ok then
		warn(`[BuildServiceClient] {result}`)
	end
end

function BuildServiceClient:_removeHovered()
	local gridX, gridY = self:_currentGrid()
	if not gridX or not gridY or not self.GridState then
		return
	end

	local guid = self.GridState.Occupied[GridMath.Key(gridX, gridY)]
	if not guid then
		return
	end

	local ok, result = self.Remote:InvokeServer("Remove", {
		Guid = guid,
	})

	if ok and type(result) == "table" then
		self.GridState.Occupied = result.Occupied or self.GridState.Occupied
	elseif not ok then
		warn(`[BuildServiceClient] {result}`)
	end
end

-- local controller = BuildServiceClient.new()

return {
	OnStart = function()
		-- BuildService is intentionally paused. Keep the controller module available
		-- without requesting BuildAction until the placement flow resumes.
	end,
}
