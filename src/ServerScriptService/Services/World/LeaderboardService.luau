local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local Observers = require(ReplicatedStorage.Packages.Observers)

local LeaderboardService = {}
local Initialized = false
local BoardEntities: { number } = {}

local BOARD_UPDATE_INTERVAL = 600
local DATASTORE_WRITE_COOLDOWN = 300
local DATASTORE_WRITE_STEP = 8
local MIN_REQUEST_BUDGET = 2
local RESET_PAGE_SIZE = 100
local MAX_RESET_PAGES = 20

local REQUEST_TYPES = {}
for _, requestType in Enum.DataStoreRequestType:GetEnumItems() do
	REQUEST_TYPES[requestType.Name] = requestType
end

local BOARD_CONFIGS = {
	{
		id = "Kills",
		dataStore = "TopKills",
		statName = "Kills",
		modelName = "MostKillsLeaderboard",
		scoreFormatter = function(value)
			return tostring(math.floor(tonumber(value) or 0))
		end,
	},
	{
		id = "Cash",
		dataStore = "TopCash",
		statName = "Cash",
		modelName = "MostCashLeaderboard",
		scoreFormatter = function(value)
			local rounded = math.floor(tonumber(value) or 0)
			local text = tostring(rounded)
			local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

			if formatted:sub(1, 1) == "," then
				formatted = formatted:sub(2)
			end

			return "$" .. formatted
		end,
	},
}

local function hasDataStoreBudget(requestTypeName)
	local requestType = REQUEST_TYPES[requestTypeName]
	if not requestType then
		return true
	end

	return DataStoreService:GetRequestBudgetForRequestType(requestType) >= MIN_REQUEST_BUDGET
end

local function getLeaderboardKey(config, userId)
	return config.statName .. tostring(userId)
end

local function getUserIdFromKey(config, key)
	return tonumber(string.split(key, config.statName)[2]) or 0
end

local function clearBoardRuntimeState(board)
	table.clear(board.usernameCache)
	table.clear(board.thumbnailCache)
	table.clear(board.lastWriteByUserId)
	table.clear(board.lastPublishedValueByUserId)
	table.clear(board.pendingValuesByUserId)
	table.clear(board.pendingWriteScheduled)
	table.clear(board.forceWriteByUserId)
	table.clear(board.writeQueuedByUserId)
	board.writeQueue = {}
	board.lastAnyWrite = 0
end

local function createBoard(config)
	return {
		config = config,
		datastore = DataStoreService:GetOrderedDataStore(config.dataStore),
		leaderboardModel = nil,
		scoreBlock = nil,
		updateBoardTimer = nil,
		usernameCache = {},
		thumbnailCache = {},
		trackedPlayers = {},
		trackedStats = {},
		playerConnections = {},
		playerObserverStop = nil,
		lastWriteByUserId = {},
		lastPublishedValueByUserId = {},
		pendingValuesByUserId = {},
		pendingWriteScheduled = {},
		writeQueue = {},
		writeQueuedByUserId = {},
		forceWriteByUserId = {},
		lastAnyWrite = 0,
		secondsUntilBoardUpdate = BOARD_UPDATE_INTERVAL,
	}
end

function LeaderboardService.ResetUser(userOrUserId)
	local userId = if typeof(userOrUserId) == "Instance" and userOrUserId:IsA("Player")
		then userOrUserId.UserId
		else tonumber(userOrUserId)
	if not userId then
		return false, "Invalid user"
	end

	for _, entity in BoardEntities do
		local board = ECS.world:get(entity, ECS.Components.LeaderboardBoard)
		if board then
			local key = getLeaderboardKey(board.config, userId)
			local success, err = pcall(function()
				board.datastore:RemoveAsync(key)
			end)
			if not success then
				warn("[LeaderboardService] Failed to reset user " .. tostring(userId) .. ": " .. tostring(err))
			end
			board.usernameCache[userId] = nil
			board.thumbnailCache[userId] = nil
			board.lastWriteByUserId[userId] = nil
			board.lastPublishedValueByUserId[userId] = nil
			board.pendingValuesByUserId[userId] = nil
			board.pendingWriteScheduled[userId] = nil
			board.forceWriteByUserId[userId] = nil
			board.writeQueuedByUserId[userId] = nil
			ECS.world:set(entity, ECS.Components.LeaderboardBoard, board)
			LeaderboardService.ClearBoard(board)
			LeaderboardService.UpdateBoard(board)
		end
	end

	return true
end

function LeaderboardService.ResetAll()
	local removedByBoard = {}
	for _, entity in BoardEntities do
		local board = ECS.world:get(entity, ECS.Components.LeaderboardBoard)
		if board then
			removedByBoard[board.config.id] = LeaderboardService.ResetBoardData(board)
			ECS.world:set(entity, ECS.Components.LeaderboardBoard, board)
		end
	end
	return true, removedByBoard
end

function LeaderboardService.ResetBoardData(board)
	local removed = 0
	for _ = 1, MAX_RESET_PAGES do
		if not hasDataStoreBudget("GetSortedAsync") or not hasDataStoreBudget("SetIncrementSortedAsync") then
			break
		end

		local success, pages = pcall(function()
			return board.datastore:GetSortedAsync(false, RESET_PAGE_SIZE, 0)
		end)

		if not success or not pages then
			warn(`[LeaderboardService] Failed to read leaderboard reset page for {board.config.statName}: {pages}`)
			break
		end

		local entries = pages:GetCurrentPage()
		if #entries == 0 then
			break
		end

		for _, entry in entries do
			local removeSuccess, err = pcall(function()
				board.datastore:RemoveAsync(entry.key)
			end)

			if removeSuccess then
				removed += 1
			else
				warn(`[LeaderboardService] Failed to remove leaderboard key {entry.key}: {err}`)
			end
		end

		if #entries < RESET_PAGE_SIZE then
			break
		end

		task.wait(1)
	end

	clearBoardRuntimeState(board)
	LeaderboardService.ClearBoard(board)
	LeaderboardService.UpdateBoard(board)

	return removed
end

function LeaderboardService.Init()
	if Initialized then
		return
	end

	for _, config in BOARD_CONFIGS do
		local board = createBoard(config)
		local entity = ECS.createEntity({
			Name = "Leaderboard:" .. config.id,
			LeaderboardBoard = board,
		})
		table.insert(BoardEntities, entity)
		LeaderboardService.BindBoard(board)
		LeaderboardService.BindPlayers(board)
		board.secondsUntilBoardUpdate = BOARD_UPDATE_INTERVAL

		local Loaded = LeaderboardService.UpdateBoard(board)
		if not Loaded then
			board.secondsUntilBoardUpdate = 1
		end
		ECS.world:set(entity, ECS.Components.LeaderboardBoard, board)

		ECS.createEntity({
			Name = "Leaderboard:" .. config.id .. ":BoardTimer",
			LeaderboardBoardTick = { Remaining = 1, Interval = 1, BoardId = entity },
		})
		ECS.createEntity({
			Name = "Leaderboard:" .. config.id .. ":WriteFlush",
			LeaderboardWriteFlush = { Remaining = 2, Interval = 2, BoardId = entity },
		})
	end

	Initialized = true
end

function LeaderboardService.TickBoardActive(entity)
	local board = ECS.world:get(entity, ECS.Components.LeaderboardBoard)
	if board then
		LeaderboardService.TickBoardTimer(board)
		ECS.world:set(entity, ECS.Components.LeaderboardBoard, board)
	end
end

function LeaderboardService.FlushWriteActive(entity)
	local board = ECS.world:get(entity, ECS.Components.LeaderboardBoard)
	if board then
		LeaderboardService.FlushNextWrite(board)
		ECS.world:set(entity, ECS.Components.LeaderboardBoard, board)
	end
end

function LeaderboardService.BindBoard(board)
	local config = board.config
	local model = workspace:FindFirstChild(config.modelName)
	if not model then
		warn(`[LeaderboardService] Missing workspace.{config.modelName}`)
		return
	end

	board.leaderboardModel = model
	board.scoreBlock = model:FindFirstChild("ScoreBlock")
	local UpdateBoardTimer = model:FindFirstChild("UpdateBoardTimer")
	local Timer = UpdateBoardTimer and UpdateBoardTimer:FindFirstChild("Timer")
	board.updateBoardTimer = Timer and Timer:FindFirstChild("TextLabel")

	if not board.scoreBlock then
		warn(`[LeaderboardService] {config.modelName}.ScoreBlock was not found`)
	end
end

function LeaderboardService.BindPlayers(board)
	if board.playerObserverStop then
		return
	end

	board.playerObserverStop = Observers.observePlayer(function(player: Player)
		LeaderboardService.TrackPlayer(board, player)

		return function()
			LeaderboardService.FlushPlayer(board, player)

			local connections = board.playerConnections[player]
			if connections then
				for _, connection in connections do
					connection:Disconnect()
				end
				board.playerConnections[player] = nil
			end

			for stat, trackedPlayer in board.trackedStats do
				if trackedPlayer == player then
					board.trackedStats[stat] = nil
				end
			end

			board.trackedPlayers[player] = nil
		end
	end)
end

function LeaderboardService.TrackPlayer(board, player)
	if board.trackedPlayers[player] then
		return
	end

	board.trackedPlayers[player] = true
	local connections = {}
	board.playerConnections[player] = connections
	local function connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end

	local function bindStat(stat)
		if not stat:IsA("IntValue") and not stat:IsA("NumberValue") then
			return
		end
		if board.trackedStats[stat] then
			return
		end

		board.trackedStats[stat] = player
		LeaderboardService.PublishValue(board, player, stat.Value, false)

		connect(stat.Changed, function(value)
			LeaderboardService.PublishValue(board, player, tonumber(value) or 0, false)
		end)
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local stat = leaderstats:FindFirstChild(board.config.statName)
		if stat then
			bindStat(stat)
		end

		connect(leaderstats.ChildAdded, function(child)
			if child.Name == board.config.statName then
				bindStat(child)
			end
		end)
	end

	connect(player.ChildAdded, function(child)
		if child.Name ~= "leaderstats" then
			return
		end

		local stat = child:FindFirstChild(board.config.statName)
		if stat then
			bindStat(stat)
		end

		connect(child.ChildAdded, function(newStat)
			if newStat.Name == board.config.statName then
				bindStat(newStat)
			end
		end)
	end)
end

function LeaderboardService.PublishValue(board, player, value, force)
	local normalizedValue = math.max(0, math.floor(value))
	if board.lastPublishedValueByUserId[player.UserId] == normalizedValue then
		board.pendingValuesByUserId[player.UserId] = nil
		return
	end

	local now = os.clock()
	local lastWrite = board.lastWriteByUserId[player.UserId] or 0

	if not force and lastWrite > 0 and now - lastWrite < DATASTORE_WRITE_COOLDOWN then
		board.pendingValuesByUserId[player.UserId] = normalizedValue
		LeaderboardService.EnqueueWrite(board, player.UserId)
		return
	end

	board.pendingValuesByUserId[player.UserId] = normalizedValue
	if force then
		board.forceWriteByUserId[player.UserId] = true
	end
	LeaderboardService.EnqueueWrite(board, player.UserId)
end

function LeaderboardService.EnqueueWrite(board, userId)
	if board.writeQueuedByUserId[userId] then
		return
	end

	board.writeQueuedByUserId[userId] = true
	table.insert(board.writeQueue, userId)
end

function LeaderboardService.FlushNextWrite(board)
	if #board.writeQueue == 0 then
		return
	end

	if os.clock() - board.lastAnyWrite < DATASTORE_WRITE_STEP then
		return
	end

	if not hasDataStoreBudget("SetIncrementSortedAsync") then
		return
	end

	local userId = table.remove(board.writeQueue, 1)
	board.writeQueuedByUserId[userId] = nil

	local pendingValue = board.pendingValuesByUserId[userId]
	if pendingValue == nil then
		return
	end

	local lastWrite = board.lastWriteByUserId[userId] or 0
	local isForced = board.forceWriteByUserId[userId] == true
	if not isForced and lastWrite > 0 and os.clock() - lastWrite < DATASTORE_WRITE_COOLDOWN then
		LeaderboardService.EnqueueWrite(board, userId)
		return
	end

	board.lastAnyWrite = os.clock()
	local key = getLeaderboardKey(board.config, userId)
	local success, err = pcall(function()
		board.datastore:SetAsync(key, pendingValue)
	end)

	if success then
		board.lastWriteByUserId[userId] = os.clock()
		board.lastPublishedValueByUserId[userId] = pendingValue
		board.pendingValuesByUserId[userId] = nil
		board.forceWriteByUserId[userId] = nil
	else
		warn(`[LeaderboardService] Failed to publish {board.config.statName} for user {userId}: {err}`)
		LeaderboardService.EnqueueWrite(board, userId)
	end
end

function LeaderboardService.FlushPlayer(board, player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(board.config.statName)
	if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue")) then
		LeaderboardService.PublishValue(board, player, stat.Value, true)
	end
end

function LeaderboardService.TickBoardTimer(board)
	if not board.scoreBlock or not board.scoreBlock.Parent then
		LeaderboardService.BindBoard(board)
	end

	board.secondsUntilBoardUpdate -= 1
	if board.updateBoardTimer and board.updateBoardTimer:IsA("TextLabel") then
		board.updateBoardTimer.Text = `Updating the board in {board.secondsUntilBoardUpdate} seconds`
	end

	if board.secondsUntilBoardUpdate <= 0 then
		if LeaderboardService.UpdateBoard(board) then
			board.secondsUntilBoardUpdate = BOARD_UPDATE_INTERVAL
		else
			board.secondsUntilBoardUpdate = 30
		end
	end
end

function LeaderboardService.ClearBoard(board)
	local scoreBlock = board.scoreBlock
	if not scoreBlock then
		return
	end

	local leaderboard = scoreBlock:FindFirstChild("Leaderboard")
	if not leaderboard then
		return
	end

	for _, folderName in { "Names", "Photos", "Score" } do
		local folder = leaderboard:FindFirstChild(folderName)
		if not folder then
			continue
		end

		for _, item in folder:GetChildren() do
			if item:IsA("GuiObject") then
				item.Visible = false
			end
		end
	end
end

function LeaderboardService.UpdateBoard(board)
	local scoreBlock = board.scoreBlock
	if not scoreBlock then
		LeaderboardService.BindBoard(board)
		scoreBlock = board.scoreBlock
		if not scoreBlock then
			return false
		end
	end

	if not hasDataStoreBudget("GetSortedAsync") then
		return false
	end

	local success, results = pcall(function()
		return board.datastore:GetSortedAsync(false, 10, 0):GetCurrentPage()
	end)

	if not success or not results then
		warn(`[LeaderboardService] Failed to retrieve top {board.config.statName}: {results}`)
		return false
	end

	local leaderboard = scoreBlock:FindFirstChild("Leaderboard")
	if not leaderboard then
		warn(`[LeaderboardService] {board.config.modelName}.ScoreBlock.Leaderboard was not found`)
		return false
	end

	local credits = scoreBlock:FindFirstChild("Credits")
	local noDataFound = scoreBlock:FindFirstChild("NoDataFound")
	if credits and credits:IsA("LayerCollector") then
		credits.Enabled = true
	end
	if leaderboard:IsA("LayerCollector") then
		leaderboard.Enabled = #results ~= 0
	end
	if noDataFound and noDataFound:IsA("LayerCollector") then
		noDataFound.Enabled = #results == 0
	end

	LeaderboardService.ClearBoard(board)

	for rank, entry in results do
		local userId = getUserIdFromKey(board.config, entry.key)
		local name = if userId <= 0 then "Studio Test Profile" else LeaderboardService.GetUsernameAsync(board, userId)
		local thumbnail = if userId <= 0
			then "rbxassetid://11569282129"
			else LeaderboardService.GetThumbnailAsync(board, userId)
		local score = board.config.scoreFormatter(entry.value)

		local names = leaderboard:FindFirstChild("Names")
		local scores = leaderboard:FindFirstChild("Score")
		local photos = leaderboard:FindFirstChild("Photos")
		local nameLabel = names and names:FindFirstChild("Name" .. rank)
		local scoreLabel = scores and scores:FindFirstChild("Score" .. rank)
		local photoLabel = photos and photos:FindFirstChild("Photo" .. rank)

		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Visible = true
			nameLabel.Text = name
		end
		if scoreLabel and scoreLabel:IsA("TextLabel") then
			scoreLabel.Visible = true
			scoreLabel.Text = score
		end
		if photoLabel and photoLabel:IsA("ImageLabel") then
			photoLabel.Visible = true
			photoLabel.Image = thumbnail
		end
	end

	local backside = scoreBlock:FindFirstChild("_backside")
	if backside then
		backside:Destroy()
	end

	if leaderboard:IsA("SurfaceGui") then
		local temp = leaderboard:Clone()
		temp.Parent = scoreBlock
		temp.Name = "_backside"
		temp.Face = Enum.NormalId.Back
	end

	return true
end

function LeaderboardService.GetUsernameAsync(board, userId)
	if board.usernameCache[userId] then
		return board.usernameCache[userId]
	end

	local success, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if not success then
		return "Name not found"
	end

	board.usernameCache[userId] = result
	return result
end

function LeaderboardService.GetThumbnailAsync(board, userId)
	if board.thumbnailCache[userId] then
		return board.thumbnailCache[userId]
	end

	local success, result = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)

	if not success then
		return "rbxassetid://5107154082"
	end

	board.thumbnailCache[userId] = result
	return result
end

return LeaderboardService
