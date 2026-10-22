local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildCatalog = require(ReplicatedStorage.BuildService.BuildCatalog)
local GridState = require(script.GridState)
local BuildSpawner = require(script.BuildSpawner)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local Factory = require(ServerScriptService.ECS.TycoonFactory)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)

local BuildService = {}

local CELL_SIZE = 4
local BUILD_POLICY = { Rate = 20, Burst = 30 }

local function isFiniteNumber(value): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

function BuildService.create(playerService, tycoonService)
	local self = {}
	self.PlayerService = playerService
	self.TycoonService = tycoonService
	self.GridStates = {}
	self.MissingCompounds = {}
	self.Spawner = BuildSpawner.create()
	return self
end

function BuildService:Init()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local action = remotes:FindFirstChild("BuildAction")
	if not action then
		action = Instance.new("RemoteFunction")
		action.Name = "BuildAction"
		action.Parent = remotes
	end

	assert(action:IsA("RemoteFunction"), "Remotes.BuildAction must be a RemoteFunction")
	local buildAction = action :: RemoteFunction
	buildAction.OnServerInvoke = function(player: Player, request: string, payload)
		if not NetworkGuard.Allow(player, "BuildAction", BUILD_POLICY, nil) then
			return false, "Please wait before trying again."
		end

		if request == "GetState" then
			return self:GetState(player)
		elseif request == "Place" then
			return self:Place(player, payload)
		elseif request == "Remove" then
			return self:Remove(player, payload)
		end

			return false, "Unknown build action."
	end
end

function BuildService:_profileBuildData(player: Player)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return nil
	end

	if type(profile.Data.BuildService) ~= "table" then
		profile.Data.BuildService = {
			PlacedBuilds = {},
		}
	end

	if type(profile.Data.BuildService.PlacedBuilds) ~= "table" then
		profile.Data.BuildService.PlacedBuilds = {}
	end

	return profile.Data.BuildService
end

function BuildService:_compoundFor(tycoonEntity)
	local model = Factory.getModel(tycoonEntity)
	local compound = model and model:FindFirstChild("Compound", true)
	if compound and compound:IsA("BasePart") then
		return compound
	end
	return nil
end

function BuildService:_stateFor(tycoon)
	local state = self.GridStates[tycoon]
	if state then
		return state
	end

	local compound = self:_compoundFor(tycoon)
	if not compound then
		if not self.MissingCompounds[tycoon] then
			self.MissingCompounds[tycoon] = true
		end
		return nil
	end

	state = GridState.create(compound, CELL_SIZE)
	self.GridStates[tycoon] = state
	return state
end

function BuildService:_hasBuilderEquipped(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child.Name == "Builder" then
			return true
		end
	end

	return false
end

function BuildService:GetState(player: Player)
	local tycoon = self.TycoonService:GetTycoonForPlayer(player)
	if not tycoon then
		return false, "Claim a tycoon first."
	end

	local state = self:_stateFor(tycoon)
	if not state then
		return false, "This tycoon is missing a Compound part."
	end

	return true, {
		Metadata = state.Metadata,
		Occupied = GridState.ExportOccupancy(state),
	}
end

function BuildService:Place(player: Player, payload)
	if type(payload) ~= "table" then
		return false, "Invalid build request."
	end

	if not self:_hasBuilderEquipped(player) then
		return false, "Equip the builder first."
	end

	local buildId = tostring(payload.BuildId or "Wood")
	local tierName = tostring(payload.Tier or BuildCatalog.DefaultTier)
	local gridXValue = tonumber(payload.GridX)
	local gridYValue = tonumber(payload.GridY)
	local rotationValue = tonumber(payload.Rotation)
	if #buildId > 64 or #tierName > 32 then
		warn(`[BuildService] {player.Name} build/tier identifier exceeded size limit`)
		return false, "Invalid build request."
	end
	if not isFiniteNumber(gridXValue) or not isFiniteNumber(gridYValue) or not isFiniteNumber(rotationValue) then
		warn(`[BuildService] {player.Name} placement coordinates were missing or non-finite`)
		return false, "Invalid placement coordinates."
	end
	local gridX = math.floor(gridXValue)
	local gridY = math.floor(gridYValue)
	local rotation = math.floor(rotationValue)
	local tier = BuildCatalog:GetTier(buildId, tierName)
	if not tier then
		return false, "Unknown build tier."
	end

	local profile = ProfileManager.Profiles[player]
	if not profile then
		return false, "Profile unavailable."
	end

	if profile.Data.Cash < tier.Cost then
		return false, "Not enough cash."
	end

	local tycoon = self.TycoonService:GetTycoonForPlayer(player)
	if not tycoon then
		return false, "Claim a tycoon first."
	end

	local state = self:_stateFor(tycoon)
	if not state then
		return false, "This tycoon is missing a Compound part."
	end

	local canPlace, reason = GridState.CanPlace(state, buildId, gridX, gridY, rotation)
	if not canPlace then
		return false, reason or "Cannot place there."
	end

	ProfileManager.AddCash(player, -tier.Cost)

	local placement = {
		Guid = HttpService:GenerateGUID(false),
		BuildId = buildId,
		Tier = tierName,
		GridX = gridX,
		GridY = gridY,
		Rotation = rotation,
	}

	GridState.Add(state, placement)
	self.Spawner:Spawn(Factory.getModel(tycoon), placement, state.Compound, state.CellSize)

	local buildData = self:_profileBuildData(player)
	if buildData then
		table.insert(buildData.PlacedBuilds, placement)
	end

	return true, {
		Message = "Build placed.",
		Placement = placement,
		Occupied = GridState.ExportOccupancy(state),
	}
end

function BuildService:Remove(player: Player, payload)
	if type(payload) ~= "table" then
		return false, "Invalid remove request."
	end

	if not self:_hasBuilderEquipped(player) then
		return false, "Equip the builder first."
	end

	local guid = tostring(payload.Guid or "")
	if guid == "" then
		return false, "Missing build id."
	end

	local tycoon = self.TycoonService:GetTycoonForPlayer(player)
	local state = tycoon and self:_stateFor(tycoon)
	if not tycoon or not state then
		return false, "No build grid available."
	end

	local placement = GridState.Remove(state, guid)
	if not placement then
		return false, "Build was not found."
	end

	local tier = BuildCatalog:GetTier(placement.BuildId, placement.Tier)
	if tier then
		ProfileManager.AddCash(player, math.floor(tier.Cost * tier.RefundRate))
	end

	self.Spawner:Destroy(Factory.getModel(tycoon), guid)

	local buildData = self:_profileBuildData(player)
	if buildData then
		for index = #buildData.PlacedBuilds, 1, -1 do
			if buildData.PlacedBuilds[index].Guid == guid then
				table.remove(buildData.PlacedBuilds, index)
				break
			end
		end
	end

	return true, {
		Message = "Build removed.",
		Occupied = GridState.ExportOccupancy(state),
	}
end

function BuildService:ReleaseTycoon(tycoon)
	local model = Factory.getModel(tycoon)
local container = model and model:FindFirstChild("PlacedBuilds")
	if container then
		container:Destroy()
	end

	self.GridStates[tycoon] = nil
	self.MissingCompounds[tycoon] = nil
end

function BuildService:ClearPlayer(player: Player, tycoon)
	local buildData = self:_profileBuildData(player)
	if buildData then
		table.clear(buildData.PlacedBuilds)
	end

	if tycoon then
		self:ReleaseTycoon(tycoon)
	end
end

function BuildService:RestorePlayer(player: Player, tycoon)
	local buildData = self:_profileBuildData(player)
	if not buildData then
		return
	end

	local state = self:_stateFor(tycoon)
	if not state then
		return
	end

	for _, placement in buildData.PlacedBuilds do
		if placement.Guid and placement.BuildId then
			local canPlace = GridState.CanPlace(state, placement.BuildId, placement.GridX or 0, placement.GridY or 0, placement.Rotation or 0)
			if canPlace then
				GridState.Add(state, placement)
				self.Spawner:Spawn(Factory.getModel(tycoon), placement, state.Compound, state.CellSize)
			else
				warn(`[BuildService] Skipped invalid saved placement {tostring(placement.Guid)} for {player.Name}`)
			end
		else
			warn(`[BuildService] Skipped malformed saved build data for {player.Name}`)
		end
	end
end

return BuildService
