
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Packages.signal)
local Janitor = require(ReplicatedStorage.Packages.janitor)
local QuestOptions = require(ReplicatedStorage.Progression.Quests.QuestOptions)
local SettingsConfig = require(ReplicatedStorage.Modules.SettingsManager.SettingsConfig)
local ClientSignals = require(ReplicatedStorage.Network.ClientSignals)
local TutorialSignals = require(ReplicatedStorage.Network.TutorialSignals)

export type Stats = {
	Cash: number,
	Emerald: number,
	Kills: number,
	Rebirths: number,
	Level: number,
	Experience: number,
}

export type QuestProgress = {
	Progress: number,
	Completed: boolean,
	Claimed: boolean,
}

export type ProfileState = {
	hydrated: boolean,
	level: number,
	experience: number,
	requiredExperience: number,
	onboarding: boolean,
	dailyReadyAt: number,
	dailySecondsRemaining: number,
	dailyQuestSecondsRemaining: number,
	weeklyQuestSecondsRemaining: number,
	quests: { [string]: QuestProgress },
}

export type Notification = {
	id: number,
	kind: string,
	message: string,
	createdAt: number,
	duration: number,
}

export type KOTHAnnouncement = {
	id: number,
	playerName: string,
	teamColor: Color3,
	minutes: number?,
	createdAt: number,
	duration: number,
}

export type ConversationOption = {
	id: string,
	text: string,
	tone: string,
}

export type NPCConversation = {
	conversationId: string,
	npcName: string,
	npcLine: string,
	options: { ConversationOption },
	turnCount: number,
	maxTurns: number,
}

export type NukeCinematic = {
	active: boolean,
	action: string,
	sessionId: string,
	role: string?,
	phase: string?,
	message: string,
	launcherName: string?,
	defenderName: string?,
	launcherUserId: string?,
	defenderUserId: string?,
	winnerName: string?,
	targetPosition: Vector3?,
	sourcePosition: Vector3?,
	distance: number?,
	deathRange: number?,
	timeLeft: number?,
	launcherScore: number,
	defenderScore: number,
}

export type Snapshot = {
	stats: Stats,
	profile: ProfileState,
	notifications: { Notification },
	kothAnnouncement: KOTHAnnouncement?,
	npcConversation: NPCConversation?,
	nukeCinematic: NukeCinematic?,
}

local DEFAULT_STATS: Stats = {
	Cash = 0,
	Emerald = 0,
	Kills = 0,
	Rebirths = 0,
	Level = 1,
	Experience = 0,
}

local DEFAULT_PROFILE: ProfileState = {
	hydrated = false,
	level = 1,
	experience = 0,
	requiredExperience = 120,
	onboarding = false,
	dailyReadyAt = 0,
	dailySecondsRemaining = 86400,
	dailyQuestSecondsRemaining = 86400,
	weeklyQuestSecondsRemaining = 604800,
	quests = QuestOptions.createProgressMap(),
}

local GameStore = {}
GameStore.__index = GameStore

local nextNotificationId = 0
local nextKothAnnouncementId = 0
local singleton = nil
local lastWeatherNotificationKind = nil
local cachedPackets = nil
local cachedReplica = nil
local replicaRequested = false
local nextPacketsRetryAt = 0

local function packetsNamespaceReady(): boolean
	local storage = ReplicatedStorage:FindFirstChild("BytenetStorage")
	local namespaceValue = storage and storage:FindFirstChild("ArmouredTycoon")
	return namespaceValue ~= nil and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= ""
end

local function getPackets()
	if RunService:IsStudio() and not RunService:IsRunning() then
		return nil
	end

	if not packetsNamespaceReady() then
		return nil
	end

	if os.clock() < nextPacketsRetryAt then
		return nil
	end

	if not cachedPackets then
		local ok, result = pcall(function()
			return require(ReplicatedStorage.Network.Packets)
		end)
		if not ok then
			nextPacketsRetryAt = os.clock() + 2
			return nil
		end
		cachedPackets = result
	end

	return cachedPackets
end

local function getReplica()
	if RunService:IsStudio() and not RunService:IsRunning() then
		return nil
	end

	if not cachedReplica then
		local ok, result = pcall(function()
			return require(ReplicatedStorage.Packages.replica)
		end)
		if not ok then
			return nil
		end
		cachedReplica = result
	end

	return cachedReplica
end

local function addCleanup(janitor, object: any, methodName: any?, index: any?)
	if object == nil then
		return nil
	end

	local cleanupMethod = methodName
	if cleanupMethod == nil then
		if typeof(object) == "RBXScriptConnection" then
			cleanupMethod = "Disconnect"
		elseif type(object) == "function" or type(object) == "thread" then
			cleanupMethod = true
		elseif type(object) == "table" and type(object.Disconnect) == "function" then
			cleanupMethod = "Disconnect"
		else
			cleanupMethod = "Destroy"
		end
	end

	janitor:Add(object, cleanupMethod, index)
	return object
end

local function copyStats(stats: Stats): Stats
	return {
		Cash = stats.Cash,
		Emerald = stats.Emerald,
		Kills = stats.Kills,
		Rebirths = stats.Rebirths,
		Level = stats.Level,
		Experience = stats.Experience,
	}
end

local function copyProfile(profile: ProfileState): ProfileState
	local quests = {}
	for questId, quest in pairs(profile.quests) do
		quests[questId] = table.clone(quest)
	end

	return {
		hydrated = profile.hydrated,
		level = profile.level,
		experience = profile.experience,
		requiredExperience = profile.requiredExperience,
		onboarding = profile.onboarding,
		dailyReadyAt = profile.dailyReadyAt,
		dailySecondsRemaining = profile.dailySecondsRemaining,
		dailyQuestSecondsRemaining = profile.dailyQuestSecondsRemaining,
		weeklyQuestSecondsRemaining = profile.weeklyQuestSecondsRemaining,
		quests = quests,
	}
end

local function copyNotifications(notifications: { Notification }): { Notification }
	local copy = table.create(#notifications)
	for index, notification in ipairs(notifications) do
		copy[index] = notification
	end

	return copy
end

local function readLeaderstat(player: Player, statName: string): number?
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(statName)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
		return value.Value
	end

	return nil
end

local function suppressUserAnnouncements(): boolean
	local player = Players.LocalPlayer
	local attributeValue = player:GetAttribute("SuppressUserAnnouncements")
	if typeof(attributeValue) == "boolean" then
		return attributeValue
	end

	return SettingsConfig.default_settings["User Announcements"] ~= true
end

local function allowNPCConversations(): boolean
	return true
end

local function isTutorialNotificationKind(kind: string): boolean
	return kind == "Perfect!"
		or kind == "Now purchase your first button!"
		or kind == "Claim your money"
		or kind == "Congrats! Tutorial Completed."
end

local function startProfileReplica(store)
	local Replica = getReplica()
	if not Replica then
		return
	end

	addCleanup(store._janitor, Replica.OnNew("ProfileState", function(replica)
		if not store._started then
			return
		end

		store._profileReplicaJanitor:Cleanup()
		store:SetProfileState(replica.Data)
		addCleanup(store._profileReplicaJanitor, replica:OnChange(function()
			store:SetProfileState(replica.Data)
		end), "Disconnect", "ProfileStateChanged")
	end), nil, "ProfileStateOnNew")

	if not replicaRequested then
		replicaRequested = true
		Replica.RequestData()
	end
end

function GameStore.new()
	local self = setmetatable({}, GameStore)

	self._stats = copyStats(DEFAULT_STATS)
	self._profile = copyProfile(DEFAULT_PROFILE)
	self._notifications = {}
	self._kothAnnouncement = nil
	self._npcConversation = nil
	self._nukeCinematic = nil
	self._changed = Signal.new()
	self._started = false
	self._destroyed = false
	self._janitor = Janitor.new()
	self._leaderstatsJanitor = Janitor.new()
	self._profileReplicaJanitor = Janitor.new()

	return self
end

function GameStore:Start()
	if self._started then
		return
	end

	self._started = true
	self:_hydrateFromLeaderstats()
	self:_bindLeaderstats()

	addCleanup(self._janitor, self._leaderstatsJanitor, "Destroy", "Leaderstats")
	addCleanup(self._janitor, self._profileReplicaJanitor, "Destroy", "ProfileReplica")
	addCleanup(self._janitor, ClientSignals.Listen(function(kind: string, value: any?)
		self:PushLegacyNotification(kind, value)
	end), nil, "ClientSignals")
	addCleanup(self._janitor, TutorialSignals.Listen(function(kind: string, value: string?)
		if isTutorialNotificationKind(kind) then
			self:PushLegacyNotification(kind, value)
		end
	end), nil, "TutorialSignals")

	addCleanup(self._janitor, task.spawn(function()
		local Packets = nil
		while self._started and not Packets do
			Packets = getPackets()
			if not Packets then
				task.wait(0.5)
			end
		end

		if not self._started or not Packets then
			return
		end

		addCleanup(self._janitor, Packets.packets.StatSync.listen(function(data)
			self:SetStat(data.stat, data.value)
		end), nil, "StatSync")

		addCleanup(self._janitor, Packets.packets.Notification.listen(function(data)
			self:PushNotification(data.kind, data.message or "")
		end), nil, "Notification")

		addCleanup(self._janitor, Packets.packets.KOTHAnnouncement.listen(function(data)
			self:PushKOTHAnnouncement(data.playerName, data.teamColor, data.minutes)
		end), nil, "KOTHAnnouncement")

		addCleanup(self._janitor, Packets.packets.NPCConversation.listen(function(payload)
			self:_handleNPCConversation(payload)
		end), nil, "NPCConversation")

		addCleanup(self._janitor, Packets.packets.NukeCinematic.listen(function(payload)
			self:_handleNukeCinematic(payload)
		end), nil, "NukeCinematic")
	end), true, "NetworkStartThread")

	addCleanup(self._janitor, Players.LocalPlayer:GetAttributeChangedSignal("SuppressUserAnnouncements"):Connect(function()
		if suppressUserAnnouncements() and self._kothAnnouncement then
			self._kothAnnouncement = nil
			self._changed:Fire()
		end
	end), "Disconnect", "SuppressUserAnnouncements")


	addCleanup(self._janitor, task.delay(200, function()
		if not self._started then
			return
		end

		self:PushNotification("info", "You can turn off user announcements and button directions in Settings.", 6)
	end), true, "SettingsReminder")

	startProfileReplica(self)
end

function GameStore:_hydrateFromLeaderstats()
	local player = Players.LocalPlayer
	for statName in pairs(DEFAULT_STATS) do
		local value = readLeaderstat(player, statName)
		if value ~= nil then
			self._stats[statName] = value
		end
	end
end

function GameStore:_bindLeaderstats()
	local player = Players.LocalPlayer

	local function clearConnections()
		self._leaderstatsJanitor:Cleanup()
	end

	local function bindValue(value: Instance)
		if not DEFAULT_STATS[value.Name] then
			return
		end
		if not value:IsA("IntValue") and not value:IsA("NumberValue") then
			return
		end

		self:SetStat(value.Name, value.Value)
		addCleanup(self._leaderstatsJanitor, value.Changed:Connect(function(newValue)
			if typeof(newValue) == "number" then
				self:SetStat(value.Name, newValue)
			else
				self:SetStat(value.Name, value.Value)
			end
		end), "Disconnect", value.Name)
	end

	local function bindFolder(leaderstats: Instance)
		clearConnections()
		for _, child in ipairs(leaderstats:GetChildren()) do
			bindValue(child)
		end
		addCleanup(self._leaderstatsJanitor, leaderstats.ChildAdded:Connect(bindValue), "Disconnect", "LeaderstatsChildAdded")
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		bindFolder(leaderstats)
	end

	addCleanup(self._janitor, player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			bindFolder(child)
		end
	end), "Disconnect", "PlayerChildAdded")
end

function GameStore:GetSnapshot(): Snapshot
	return {
		stats = copyStats(self._stats),
		profile = copyProfile(self._profile),
		notifications = copyNotifications(self._notifications),
		kothAnnouncement = self._kothAnnouncement,
		npcConversation = self._npcConversation,
		nukeCinematic = self._nukeCinematic,
	}
end

function GameStore:Subscribe(callback: () -> ()): () -> ()
	local connection = self._changed:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function GameStore:SetStat(statName: string, value: number)
	if self._stats[statName] == nil then
		return
	end

	local rounded = math.floor(value)
	if self._stats[statName] == rounded then
		return
	end

	self._stats[statName] = rounded
	if statName == "Level" then
		self._profile.level = rounded
	elseif statName == "Experience" then
		self._profile.experience = rounded
	end
	self._changed:Fire()
end

function GameStore:SetProfileState(state: any)
	if typeof(state) ~= "table" then
		return
	end

	self._profile = {
		hydrated = true,
		level = tonumber(state.level) or self._profile.level,
		experience = tonumber(state.experience) or self._profile.experience,
		requiredExperience = tonumber(state.requiredExperience) or self._profile.requiredExperience,
		onboarding = state.onboarding == true,
		dailyReadyAt = tonumber(state.dailyReadyAt) or 0,
		dailySecondsRemaining = tonumber(state.dailySecondsRemaining) or self._profile.dailySecondsRemaining,
		dailyQuestSecondsRemaining = tonumber(state.dailyQuestSecondsRemaining) or self._profile.dailyQuestSecondsRemaining,
		weeklyQuestSecondsRemaining = tonumber(state.weeklyQuestSecondsRemaining) or self._profile.weeklyQuestSecondsRemaining,
		quests = state.quests or self._profile.quests,
	}

	self._stats.Level = self._profile.level
	self._stats.Experience = self._profile.experience
	self._changed:Fire()
end

function GameStore:ClearNotificationsByKind(kind: string)
	local changed = false
	for index = #self._notifications, 1, -1 do
		if self._notifications[index].kind == kind then
			table.remove(self._notifications, index)
			changed = true
		end
	end

	if changed then
		self._changed:Fire()
	end
end

function GameStore:PushTutorialNotification(message: string)
	self:ClearNotificationsByKind("tutorial")
	self:PushNotification("tutorial", message, 0)
end

function GameStore:PushNotification(kind: string, message: string, duration: number?)
	nextNotificationId += 1
	table.insert(self._notifications, 1, {
		id = nextNotificationId,
		kind = kind,
		message = message,
		createdAt = os.clock(),
		duration = duration or 2.35,
	})

	while #self._notifications > 4 do
		table.remove(self._notifications)
	end

	self._changed:Fire()
end

function GameStore:PushLegacyNotification(kind: string, value: any?)
	if kind == "Player1" or kind == "Player1Disconnected" then
		return
	end

	local tutorialMessageByKind = {
		["Perfect!"] = "Tycoon claimed. Follow the beam to your first button.",
		["Now purchase your first button!"] = "Purchase your first button.",
		["Claim your money"] = "Claim your money from the ATM.",
		["Congrats! Tutorial Completed."] = "Tutorial completed.",
	}

	local tutorialMessage = tutorialMessageByKind[kind]
	if tutorialMessage then
		if kind == "Congrats! Tutorial Completed." then
			self:ClearNotificationsByKind("tutorial")
			self:PushNotification("success", tutorialMessage, 3)
		else
			self:PushTutorialNotification(tutorialMessage)
		end
		return
	end

	if kind == "Weather" then
		if typeof(value) ~= "table" then
			return
		end

		local weatherKind = value.kind
		if typeof(weatherKind) ~= "string" then
			return
		end
		
	
		if weatherKind == lastWeatherNotificationKind then
			return
		end

		lastWeatherNotificationKind = weatherKind
		if weatherKind == "Storm" then
			self:PushNotification("warning", "Storm rolling in. Rain and thunder are active.", 5)
		elseif weatherKind == "Rain" then
			self:PushNotification("info", "Rain is moving through the area.", 4)
		elseif weatherKind == "Fog" then
			self:PushNotification("info", "Fog is settling across the map.", 4)
		end

		return
	end

	local messageByKind = {
		["Not Enough Cash"] = "Not enough cash",
		["Not Enough Rebirths"] = "Not enough rebirths",
		["Complete Your Tycoon First"] = "Complete your tycoon before rebirthing",
		NotFollowing = "You need to follow the requirement first",
		FuseBox = "Power restored",
		AlreadyOn = "Power is already on",
		Wires = "Find the wires first",
		Electrocuted = "You were electrocuted",
		CashCollected = if typeof(value) == "table" and typeof(value.amount) == "number"
			then `Collected ${math.floor(value.amount)} cash`
			else "Cash collected",
	}

	local message = messageByKind[kind] or tostring(kind)
	local tone = "info"

	if string.find(string.lower(message), "not enough", 1, true) or string.find(string.lower(message), "electrocuted", 1, true) then
		tone = "error"
	elseif string.find(string.lower(message), "active", 1, true) or string.find(string.lower(message), "restored", 1, true) then
		tone = "success"
	end

	self:PushNotification(tone, message)
end

function GameStore:DismissNotification(id: number)
	for index, notification in ipairs(self._notifications) do
		if notification.id == id then
			table.remove(self._notifications, index)
			self._changed:Fire()
			return
		end
	end
end

function GameStore:PushKOTHAnnouncement(playerName: string, teamColor: Color3, minutes: number?)
	if suppressUserAnnouncements() then
		return
	end

	nextKothAnnouncementId += 1
	self._kothAnnouncement = {
		id = nextKothAnnouncementId,
		playerName = playerName,
		teamColor = teamColor,
		minutes = minutes,
		createdAt = os.clock(),
		duration = 4.5,
	}

	self._changed:Fire()
end

function GameStore:DismissKOTHAnnouncement(id: number)
	if self._kothAnnouncement and self._kothAnnouncement.id == id then
		self._kothAnnouncement = nil
		self._changed:Fire()
	end
end

function GameStore:_handleNPCConversation(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.action == "End" then
		self._npcConversation = nil
		self._changed:Fire()
		return
	end

	if payload.action ~= "Open" then
		return
	end

	if not allowNPCConversations() then
		local Packets = getPackets()
		if Packets then
			Packets.packets.NPCConversationChoice.send({
				action = "End",
				conversationId = tostring(payload.conversationId or ""),
			})
		end
		return
	end

	self._npcConversation = {
		conversationId = tostring(payload.conversationId or ""),
		npcName = tostring(payload.npcName or "NPC"),
		npcLine = tostring(payload.npcLine or ""),
		options = payload.options or {},
		turnCount = tonumber(payload.turnCount) or 0,
		maxTurns = tonumber(payload.maxTurns) or 7,
	}
	self._changed:Fire()
end

function GameStore:_handleNukeCinematic(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.action == "End" then
		self._nukeCinematic = nil
		self._changed:Fire()
		return
	end

	local current = self._nukeCinematic or {
		active = true,
		action = tostring(payload.action or ""),
		sessionId = tostring(payload.sessionId or ""),
		role = payload.role,
		phase = payload.phase,
		message = tostring(payload.message or "NUCLEAR INBOUND"),
		launcherName = payload.launcherName,
		defenderName = payload.defenderName,
		launcherUserId = payload.launcherUserId,
		defenderUserId = payload.defenderUserId,
		winnerName = payload.winnerName,
		targetPosition = payload.targetPosition,
		sourcePosition = payload.sourcePosition,
		distance = payload.distance,
		deathRange = payload.deathRange,
		timeLeft = payload.timeLeft,
		launcherScore = tonumber(payload.launcherScore) or 0,
		defenderScore = tonumber(payload.defenderScore) or 0,
	}

	current.active = true
	current.action = tostring(payload.action or current.action)
	current.sessionId = tostring(payload.sessionId or current.sessionId)
	current.role = payload.role or current.role
	current.phase = payload.phase or current.phase
	current.message = tostring(payload.message or current.message)
	current.launcherName = payload.launcherName or current.launcherName
	current.defenderName = payload.defenderName or current.defenderName
	current.launcherUserId = payload.launcherUserId or current.launcherUserId
	current.defenderUserId = payload.defenderUserId or current.defenderUserId
	current.winnerName = payload.winnerName or current.winnerName
	current.targetPosition = payload.targetPosition or current.targetPosition
	current.sourcePosition = payload.sourcePosition or current.sourcePosition
	current.distance = payload.distance or current.distance
	current.deathRange = payload.deathRange or current.deathRange
	current.timeLeft = payload.timeLeft or current.timeLeft
	current.launcherScore = tonumber(payload.launcherScore) or current.launcherScore
	current.defenderScore = tonumber(payload.defenderScore) or current.defenderScore

	self._nukeCinematic = current
	self._changed:Fire()
end

function GameStore:ChooseNPCConversationOption(optionId: string)
	if not self._npcConversation then
		return
	end

	local Packets = getPackets()
	if Packets then
		Packets.packets.NPCConversationChoice.send({
			action = "Choose",
			conversationId = self._npcConversation.conversationId,
			optionId = optionId,
		})
	end
end

function GameStore:EndNPCConversation()
	local conversation = self._npcConversation
	self._npcConversation = nil
	self._changed:Fire()

	if conversation then
		local Packets = getPackets()
		if Packets then
			Packets.packets.NPCConversationChoice.send({
				action = "End",
				conversationId = conversation.conversationId,
			})
		end
	end
end

function GameStore:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._started = false
	self._janitor:Destroy()

	local changed = self._changed :: any
	if changed.Destroy then
		changed:Destroy()
	end

	if singleton == self then
		singleton = nil
	end
end

function GameStore.get()
	if not singleton then
		singleton = GameStore.new()
	end

	return singleton
end

return GameStore

