local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildCatalog = require(ReplicatedStorage.Shared.Game.Tycoon.Building.BuildCatalog)
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
local GridState = require(script.Parent.GridState)
local BuildSpawner = require(script.Parent.BuildSpawner)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local Factory = require(ServerScriptService.Game.Tycoon.TycoonFactory)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)

local TycoonQueries = require(ServerScriptService.Game.Tycoon.TycoonQueries)

local BuildService = {}
local Initialized = false
local GridStates = {}
local MissingCompounds = {}

local CELL_SIZE = 4
local BUILD_POLICY = { Rate = 20, Burst = 30 }

local function isFiniteNumber(value): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

function BuildService.Init()
	if Initialized then
		return
	end

	Initialized = true
	NetworkGuard.Query(Packets.queries.BuildAction, "BuildAction", {
		Rate = BUILD_POLICY.Rate,
		Burst = BUILD_POLICY.Burst,
		Validate = function(request)
			return type(request) == "table"
				and (request.action == "GetState" or request.action == "Place" or request.action == "Remove")
				and (request.payload == nil or (type(request.payload) == "string" and #request.payload <= 4096))
		end,
	}, function(request, player: Player)
		if request.action == "GetState" then
			local success, result = BuildService.GetState(player)
			if not success then
				return { success = false, message = tostring(result) }
			end

			local metadata = result.Metadata
			local ok, occupied = pcall(HttpService.JSONEncode, HttpService, result.Occupied)
			if not ok then
				return { success = false, message = "Build state could not be encoded." }
			end

			return {
				success = true,
				message = "",
				state = {
					cellSize = metadata.CellSize,
					width = metadata.Width,
					height = metadata.Height,
					origin = metadata.Origin,
					compoundSize = metadata.CompoundSize,
					occupied = occupied,
				},
			}
		end

		local payload = nil
		if request.payload ~= nil then
			local decoded, result = pcall(HttpService.JSONDecode, HttpService, request.payload)
			if not decoded or type(result) ~= "table" then
				return { success = false, message = "Invalid build payload." }
			end
			payload = result
		end

		local success, result
		if request.action == "Place" then
			success, result = BuildService.Place(player, payload)
		else
			success, result = BuildService.Remove(player, payload)
		end
		if not success then
			return { success = false, message = tostring(result) }
		end

		local encoded, encodedResult = pcall(HttpService.JSONEncode, HttpService, result)
		if not encoded then
			return { success = false, message = "Build result could not be encoded." }
		end
		return { success = true, message = "", payload = encodedResult }
	end)
end

function BuildService._profileBuildData(player: Player)
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

function BuildService._compoundFor(tycoonEntity)
	local model = Factory.GetModel(tycoonEntity)
	local compound = model and model:FindFirstChild("Compound", true)
	if compound and compound:IsA("BasePart") then
		return compound
	end
	return nil
end

function BuildService._stateFor(tycoon)
	local state = GridStates[tycoon]
	if state then
		return state
	end

	local compound = BuildService._compoundFor(tycoon)
	if not compound then
		if not MissingCompounds[tycoon] then
			MissingCompounds[tycoon] = true
		end
		return nil
	end

	state = GridState.create(compound, CELL_SIZE)
	GridStates[tycoon] = state
	return state
end

function BuildService._hasBuilderEquipped(player: Player): boolean
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

function BuildService.GetState(player: Player)
	local tycoon = TycoonQueries.FindOwnedTycoon(player)
	if not tycoon then
		return false, "Claim a tycoon first."
	end

	local state = BuildService._stateFor(tycoon)
	if not state then
		return false, "This tycoon is missing a Compound part."
	end

	return true, {
		Metadata = state.Metadata,
		Occupied = GridState.ExportOccupancy(state),
	}
end

function BuildService.Place(player: Player, payload)
	if type(payload) ~= "table" then
		return false, "Invalid build request."
	end

	if not BuildService._hasBuilderEquipped(player) then
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

	local tycoon = TycoonQueries.FindOwnedTycoon(player)
	if not tycoon then
		return false, "Claim a tycoon first."
	end

	local state = BuildService._stateFor(tycoon)
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
	BuildSpawner.Spawn(Factory.GetModel(tycoon), placement, state.Compound, state.CellSize)

	local buildData = BuildService._profileBuildData(player)
	if buildData then
		table.insert(buildData.PlacedBuilds, placement)
	end

	return true,
		{
			Message = "Build placed.",
			Placement = placement,
			Occupied = GridState.ExportOccupancy(state),
		}
end

function BuildService.Remove(player: Player, payload)
	if type(payload) ~= "table" then
		return false, "Invalid remove request."
	end

	if not BuildService._hasBuilderEquipped(player) then
		return false, "Equip the builder first."
	end

	local guid = tostring(payload.Guid or "")
	if guid == "" then
		return false, "Missing build id."
	end

	local tycoon = TycoonQueries.FindOwnedTycoon(player)
	local state = tycoon and BuildService._stateFor(tycoon)
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

	BuildSpawner.Destroy(Factory.GetModel(tycoon), guid)

	local buildData = BuildService._profileBuildData(player)
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

function BuildService.ReleaseTycoon(tycoon)
	local model = Factory.GetModel(tycoon)
	local container = model and model:FindFirstChild("PlacedBuilds")
	if container then
		container:Destroy()
	end

	GridStates[tycoon] = nil
	MissingCompounds[tycoon] = nil
end

function BuildService.ClearPlayer(player: Player, tycoon)
	local buildData = BuildService._profileBuildData(player)
	if buildData then
		table.clear(buildData.PlacedBuilds)
	end

	if tycoon then
		BuildService.ReleaseTycoon(tycoon)
	end
end

function BuildService.RestorePlayer(player: Player, tycoon)
	local buildData = BuildService._profileBuildData(player)
	if not buildData then
		return
	end

	local state = BuildService._stateFor(tycoon)
	if not state then
		return
	end

	for _, placement in buildData.PlacedBuilds do
		if placement.Guid and placement.BuildId then
			local canPlace = GridState.CanPlace(
				state,
				placement.BuildId,
				placement.GridX or 0,
				placement.GridY or 0,
				placement.Rotation or 0
			)
			if canPlace then
				GridState.Add(state, placement)
				BuildSpawner.Spawn(Factory.GetModel(tycoon), placement, state.Compound, state.CellSize)
			else
				warn(`[BuildService] Skipped invalid saved placement {tostring(placement.Guid)} for {player.Name}`)
			end
		else
			warn(`[BuildService] Skipped malformed saved build data for {player.Name}`)
		end
	end
end

return BuildService
