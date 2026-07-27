local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildCatalog = require(ReplicatedStorage.BuildService.BuildCatalog)
local GridState = require(script.GridState)
local BuildSpawner = require(script.BuildSpawner)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)

local BuildService = {}
BuildService.__index = BuildService

local CELL_SIZE = 4

local function isFiniteNumber(value): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

function BuildService.new(playerService, tycoonService)
	local self = setmetatable({}, BuildService)
	self.PlayerService = playerService
	self.TycoonService = tycoonService
	self.GridStates = {}
	self.LastRequests = {}
	self.MissingCompounds = {}
	self.Spawner = BuildSpawner.new()
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

	Diagnostics.invariant(action:IsA("RemoteFunction"), "BuildService", "Remotes.BuildAction must be a RemoteFunction");
	(action :: RemoteFunction).OnServerInvoke = function(player: Player, request: string, payload)
		local now = os.clock()
		local lastRequest = self.LastRequests[player] or 0
		if now - lastRequest < 0.05 then
			Diagnostics.reject(player, "BuildAction", "Request rate exceeded", 2)
			return false, "Please wait before trying again."
		end
		self.LastRequests[player] = now

		if request == "GetState" then
			return self:GetState(player)
		elseif request == "Place" then
			return self:Place(player, payload)
		elseif request == "Remove" then
			return self:Remove(player, payload)
		end

		Diagnostics.reject(player, "BuildAction", `Unknown action: {tostring(request)}`)
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

function BuildService:_compoundFor(tycoon)
	local compound = tycoon.Model:FindFirstChild("Compound", true)
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
			Diagnostics.report("BuildService", `Tycoon {tycoon.Model:GetFullName()} is missing its required Compound part`)
		end
		return nil
	end

	state = GridState.new(compound, CELL_SIZE)
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
		Occupied = state:ExportOccupancy(),
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
		Diagnostics.reject(player, "BuildAction", "Build or tier identifier exceeded its size limit")
		return false, "Invalid build request."
	end
	if not isFiniteNumber(gridXValue) or not isFiniteNumber(gridYValue) or not isFiniteNumber(rotationValue) then
		Diagnostics.reject(player, "BuildAction", "Placement coordinates were missing or non-finite")
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

	local canPlace, reason = state:CanPlace(buildId, gridX, gridY, rotation)
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

	state:Add(placement)
	self.Spawner:Spawn(tycoon, placement, state.Compound, state.CellSize)

	local buildData = self:_profileBuildData(player)
	if buildData then
		table.insert(buildData.PlacedBuilds, placement)
	end

	return true, {
		Message = "Build placed.",
		Placement = placement,
		Occupied = state:ExportOccupancy(),
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

	local placement = state:Remove(guid)
	if not placement then
		return false, "Build was not found."
	end

	local tier = BuildCatalog:GetTier(placement.BuildId, placement.Tier)
	if tier then
		ProfileManager.AddCash(player, math.floor(tier.Cost * tier.RefundRate))
	end

	self.Spawner:Destroy(tycoon, guid)

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
		Occupied = state:ExportOccupancy(),
	}
end

function BuildService:ReleaseTycoon(tycoon)
	local container = tycoon.Model:FindFirstChild("PlacedBuilds")
	if container then
		container:Destroy()
	end

	self.GridStates[tycoon] = nil
end

function BuildService:ClearPlayer(player: Player, tycoon)
	self.LastRequests[player] = nil
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
			local canPlace = state:CanPlace(placement.BuildId, placement.GridX or 0, placement.GridY or 0, placement.Rotation or 0)
			if canPlace then
				state:Add(placement)
				self.Spawner:Spawn(tycoon, placement, state.Compound, state.CellSize)
			else
				Diagnostics.reportThrottled(
					"BuildService",
					`tombstone:{player.UserId}:{tostring(placement.Guid)}`,
					`Skipped invalid saved placement {tostring(placement.Guid)} for {player.Name}`,
					60
				)
			end
		else
			Diagnostics.reportThrottled(
				"BuildService",
				`corrupt:{player.UserId}`,
				`Skipped malformed saved build data for {player.Name}`,
				60
			)
		end
	end
end

return BuildService
