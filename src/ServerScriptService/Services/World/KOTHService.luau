--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Packets = require(ReplicatedStorage.Network.Packets)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)

local KOTHService = {}
KOTHService.__index = KOTHService
local ActiveService: any? = nil

local CASH_PER_SECOND = 3000
local AWARD_INTERVAL = 1
local ANNOUNCE_INTERVAL_SECONDS = 5 * 60
local KOTH_PATH = { "MiddleSection", "KOTH" }


local function getTeamColor(player: Player): Color3
	if player.Team then
		return player.Team.TeamColor.Color
	end

	return Color3.fromRGB(255, 170, 64)
end

local function findPath(root: Instance, path: { string }): Instance?
	local current: Instance? = root

	for _, name in ipairs(path) do
		if not current then
			return nil
		end

		current = current:FindFirstChild(name)
	end

	return current
end

function KOTHService.new()
	local self = setmetatable({}, KOTHService)

	self._model = nil :: Model?
	self._contest = nil :: BasePart?
	self._kingLabel = nil :: TextLabel?
	self._contesters = {} :: { [Player]: boolean }
	self._king = nil :: Player?
	self._kingStartedAt = 0
	self._lastAnnouncedInterval = 0
	ActiveService = self

	return self
end

function KOTHService:Init()
	local model = findPath(workspace, KOTH_PATH)
	if not model or not model:IsA("Model") then
		warn("[KOTHService] workspace.Map.MiddleSection.KOTH was not found")
		return
	end

	local contest = model:FindFirstChild("Contest")
	if not contest or not contest:IsA("BasePart") then
		warn("[KOTHService] workspace.Map.MiddleSection.KOTH.Contest must be a BasePart")
		return
	end

	self._model = model
	self._contest = contest
	self._kingLabel = self:_findKingLabel(contest)

	contest.Touched:Connect(function(hit)
		self:_onTouched(hit)
	end)

	contest.TouchEnded:Connect(function(hit)
		self:_onTouchEnded(hit)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_removeContester(player)
	end)

	self:_refreshKing()

	ECS.createEntity({
		Name = "KOTH:AwardTick",
		ScheduledTask = {
			delay = AWARD_INTERVAL,
			elapsed = 0,
			repeatEvery = AWARD_INTERVAL,
			kind = "KOTHAwardTick",
		},
	})
end

function KOTHService.TickAwardActive()
	if ActiveService then
		ActiveService:_tickAward()
	end
end

function KOTHService.CheckTouchEndedActive(player: Player, character: Model)
	if ActiveService and not ActiveService:_isCharacterInZone(character) then
		ActiveService:_removeContester(player)
	end
end

function KOTHService:_findKingLabel(contest: BasePart): TextLabel?
	local king = contest:FindFirstChild("King")
	local label = king and king:FindFirstChild("TextLabel")
	if label and label:IsA("TextLabel") then
		return label
	end

	warn("[KOTHService] Contest.King.TextLabel was not found")
	return nil
end

function KOTHService:_getCharacterPlayer(hit: Instance): (Player?, Model?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end

	return player, character
end

function KOTHService:_isCharacterInZone(character: Model): boolean
	local contest = self._contest
	if not contest then
		return false
	end

	for _, part in ipairs(contest:GetTouchingParts()) do
		if part:IsDescendantOf(character) then
			return true
		end
	end

	return false
end

function KOTHService:_countContesters(): (number, Player?)
	local count = 0
	local onlyPlayer = nil

	for player in pairs(self._contesters) do
		if player.Parent == Players then
			count += 1
			onlyPlayer = player
		else
			self._contesters[player] = nil
		end
	end

	return count, onlyPlayer
end

function KOTHService:_setKingLabel(text: string)
	if self._kingLabel then
		self._kingLabel.Text = text
	end
end

function KOTHService:_announceKing(player: Player, minutes: number?)
	Packets.packets.KOTHAnnouncement.sendToAll({
		playerName = player.Name,
		teamColor = getTeamColor(player),
		minutes = minutes,
	})
end

function KOTHService:_refreshKing()
	local count, onlyPlayer = self:_countContesters()

	if count == 0 then
		self._king = nil
		self._kingStartedAt = 0
		self._lastAnnouncedInterval = 0
		self:_setKingLabel("King: Nobody")
		return
	end

	if count > 1 or not onlyPlayer then
		self._king = nil
		self._kingStartedAt = 0
		self._lastAnnouncedInterval = 0
		self:_setKingLabel("King: Contested")
		return
	end

	if self._king ~= onlyPlayer then
		self._king = onlyPlayer
		self._kingStartedAt = os.clock()
		self._lastAnnouncedInterval = 0
		self:_announceKing(onlyPlayer, nil)
	end

	self:_setKingLabel("King: " .. onlyPlayer.Name)
end

function KOTHService:_onTouched(hit: Instance)
	local player = self:_getCharacterPlayer(hit)
	if not player or self._contesters[player] then
		return
	end

	self._contesters[player] = true
	self:_refreshKing()
end

function KOTHService:_onTouchEnded(hit: Instance)
	local player, character = self:_getCharacterPlayer(hit)
	if not player or not character then
		return
	end

	ECS.createEntity({
		Name = "KOTH:TouchEndedCheck",
		ScheduledTask = {
			delay = 0.15,
			elapsed = 0,
			kind = "KOTHTouchEndedCheck",
			player = player,
			character = character,
		},
	})
end

function KOTHService:_removeContester(player: Player)
	if not self._contesters[player] then
		return
	end

	self._contesters[player] = nil
	self:_refreshKing()
end

function KOTHService:_tickAward()
	local king = self._king
	if not king or not self._contesters[king] then
		return
	end

	local character = king.Character
	if not character or not self:_isCharacterInZone(character) then
		self:_removeContester(king)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		self:_removeContester(king)
		return
	end

	local elapsed = os.clock() - self._kingStartedAt
	if elapsed < AWARD_INTERVAL then
		return
	end

	ProfileManager.AddCash(king, CASH_PER_SECOND)

	local interval = math.floor(elapsed / ANNOUNCE_INTERVAL_SECONDS)
	if interval > 0 and interval > self._lastAnnouncedInterval then
		self._lastAnnouncedInterval = interval
		self:_announceKing(king, interval * 5)
	end
end

return KOTHService
