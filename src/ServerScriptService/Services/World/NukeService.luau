--!strict
-- Authoritative nuke session coordinator. Tycoon data stays in ECS; clients render the rocket.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Packets = require(ReplicatedStorage.Network.Packets)
local Factory = require(ServerScriptService.ECS.TycoonFactory)
local TycoonRuntime = require(ServerScriptService.ECS.TycoonRuntime)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)
local ValidatePromptRange = require(ServerScriptService.Classes.Tycoon.Utilities.ValidatePromptRange)
local Notify = require(ServerScriptService.Classes.Tycoon.Utilities.Notify)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)

local ASCENT_TIME = 20
local TOTAL_FLIGHT_TIME = 50
local MASH_DURATION = TOTAL_FLIGHT_TIME - ASCENT_TIME
local NUKE_COOLDOWN = 1200
local MAX_BATCH_CLICKS = 12
local MAX_INSTANT_CPS = 32
local MAX_SUSTAINED_CPS = 24
local MIN_DEATH_RANGE = 650
local DEATH_RANGE_MULTIPLIER = 6

type ScoreState = { lastAt: number, cpsAverage: number, score: number }
type Session = {
	id: string,
	launcher: Player,
	defender: Player,
	launcherEntity: number,
	defenderEntity: number,
	defenderGeneration: number,
	sourcePosition: Vector3,
	targetPosition: Vector3,
	deathRange: number,
	launcherState: ScoreState,
	defenderState: ScoreState,
	mashOpen: boolean,
	ended: boolean,
}

local NukeService = {}
NukeService.__index = NukeService

local function findTargetPart(model: Model): BasePart?
	local mainItems = model:FindFirstChild("MainItems")
	local target = mainItems and mainItems:FindFirstChild("Target", true)
	return if target and target:IsA("BasePart") then target else nil
end

local function getDeathRange(model: Model): number
	local _, size = model:GetBoundingBox()
	return math.max(MIN_DEATH_RANGE, math.max(size.X, size.Z) * DEATH_RANGE_MULTIPLIER)
end

function NukeService.new(tycoonService: any, playerService: any)
	local self = setmetatable({}, NukeService)
	self.TycoonService = tycoonService
	self.PlayerService = playerService
	self.PromptConnections = setmetatable({}, {__mode = "k"})
	self.ModelConnections = setmetatable({}, {__mode = "k"})
	self.ActiveSession = nil
	self.Started = false
	return self
end

function NukeService:_findTarget(launcherEntity: number, launcher: Player): (number?, Player?, Vector3?)
	local launcherModel = Factory.getModel(launcherEntity)
	if not launcherModel then return nil, nil, nil end
	local source = launcherModel:GetPivot().Position
	local bestEntity, bestPlayer, bestPosition, bestDistance
	for entity, state in ECS.world:query(ECS.Components.TycoonState) do
		if entity ~= launcherEntity and state.active ~= false and state.owner and state.owner ~= launcher then
			local model = Factory.getModel(entity)
			if model then
				local part = findTargetPart(model)
				local position = if part then part.Position else model:GetPivot().Position
				local distance = (position - source).Magnitude
				if not bestDistance or distance < bestDistance then
					bestEntity, bestPlayer, bestPosition, bestDistance = entity, state.owner, position, distance
				end
			end
		end
	end
	return bestEntity, bestPlayer, bestPosition
end

function NukeService:_base(session: Session): any
	return {
		sessionId = session.id,
		launcherName = session.launcher.Name,
		defenderName = session.defender.Name,
		launcherUserId = tostring(session.launcher.UserId),
		defenderUserId = tostring(session.defender.UserId),
		sourcePosition = session.sourcePosition,
		targetPosition = session.targetPosition,
		deathRange = session.deathRange,
	}
end

function NukeService:_send(payload: any)
	Packets.packets.NukeCinematic.sendToAll(payload)
end

function NukeService:_finish(session: Session, defenderWon: boolean)
	if session.ended then return end
	session.ended = true
	session.mashOpen = false
	if self.ActiveSession == session then self.ActiveSession = nil end

	local winner = if defenderWon then session.defender else session.launcher
	local result = self:_base(session)
	result.action = "Result"
	result.winnerName = winner.Name
	result.message = if defenderWon
		then "DEFLECTION SUCCESSFUL"
		else "IMPACT AUTHORIZED"
	result.launcherScore = session.launcherState.score
	result.defenderScore = session.defenderState.score
	self:_send(result)

	local impact = self:_base(session)
	impact.action = "Impact"
	impact.message = if defenderWon then "DEFLECTION SUCCESSFUL" else "IMPACT CONFIRMED"
	self:_send(impact)

	if not defenderWon then
		local targetEntity, targetPlayer, generation = session.defenderEntity, session.defender, session.defenderGeneration
		task.delay(10, function()
			local state = Factory.getState(targetEntity)
			local owner = ECS.world:get(targetEntity, ECS.Components.Owner)
			if not state or state.active == false or not owner or owner.player ~= targetPlayer or owner.generation ~= generation then return end
			local profile = ProfileManager.Profiles[targetPlayer]
			if profile then
				local loss = math.floor(math.max(0, profile.Data.Cash) * 0.25)
				if loss > 0 then ProfileManager.AddCash(targetPlayer, -loss) end
			end
			TycoonRuntime.cleanup(targetEntity, self.PlayerService, self.PlayerService.BuildService)
		end)
	end

	task.delay(4, function()
		self:_send({action = "End", sessionId = session.id})
	end)
end

function NukeService:_click(payload: any, player: Player)
	local session = self.ActiveSession
	if not session or session.ended or not session.mashOpen or payload.sessionId ~= session.id then return end
	local scoreState = if player == session.launcher then session.launcherState elseif player == session.defender then session.defenderState else nil
	if not scoreState then return end

	local count = math.clamp(math.floor(payload.count), 0, MAX_BATCH_CLICKS)
	local window = math.clamp(payload.clientWindow, 0.05, 1)
	if count <= 0 then return end
	local now = os.clock()
	local elapsed = math.max(now - scoreState.lastAt, 0.05)
	local cps = count / math.min(elapsed, window)
	scoreState.cpsAverage = scoreState.cpsAverage * 0.58 + cps * 0.42
	scoreState.lastAt = now
	if cps > MAX_INSTANT_CPS or scoreState.cpsAverage > MAX_SUSTAINED_CPS then return end
	scoreState.score = math.clamp(scoreState.score + count, 0, 100)

	local score = self:_base(session)
	score.action = "Score"
	score.launcherScore = session.launcherState.score
	score.defenderScore = session.defenderState.score
	self:_send(score)
end

function NukeService:_start(entity: number, player: Player, prompt: ProximityPrompt)
	if self.ActiveSession and not self.ActiveSession.ended then
		Notify(player, "info", "Another nuclear launch is already in progress.")
		return
	end
	local state = Factory.getState(entity)
	local owner = ECS.world:get(entity, ECS.Components.Owner)
	if not state or not owner or owner.player ~= player then
		Notify(player, "error", "Only the tycoon owner can launch this nuke.")
		return
	end
	if state.nukeCooldownReady == false then
		Notify(player, "info", "The nuke launcher is recharging.")
		return
	end
	if not ValidatePromptRange(player, prompt) then
		Notify(player, "info", "Move closer to launch the nuke.")
		return
	end

	local defenderEntity, defender, targetPosition = self:_findTarget(entity, player)
	local model = Factory.getModel(entity)
	local targetModel = defenderEntity and Factory.getModel(defenderEntity)
	if not defenderEntity or not defender or not targetPosition or not model or not targetModel then
		Notify(player, "info", "There is no occupied tycoon to target.")
		return
	end

	state.nukeCooldownReady = false
	ECS.world:set(entity, ECS.Components.TycoonState, state)
	local button = prompt:FindFirstAncestorWhichIsA("BasePart")
	if button then button.BrickColor = BrickColor.new("Really red") end
	local targetOwner = ECS.world:get(defenderEntity, ECS.Components.Owner)
	local session: Session = {
		id = HttpService:GenerateGUID(false),
		launcher = player,
		defender = defender,
		launcherEntity = entity,
		defenderEntity = defenderEntity,
		defenderGeneration = if targetOwner then targetOwner.generation or 0 else 0,
		sourcePosition = if button then button.Position else model:GetPivot().Position,
		targetPosition = targetPosition,
		deathRange = getDeathRange(targetModel),
		launcherState = {lastAt = os.clock(), cpsAverage = 0, score = 0},
		defenderState = {lastAt = os.clock(), cpsAverage = 0, score = 0},
		mashOpen = false,
		ended = false,
	}
	self.ActiveSession = session

	local warning = self:_base(session)
	warning.action, warning.phase, warning.message = "Warning", "warning", "NUCLEAR INBOUND"
	warning.distance, warning.timeLeft = (session.sourcePosition - targetPosition).Magnitude, TOTAL_FLIGHT_TIME
	self:_send(warning)

	local launcherFocus = self:_base(session)
	launcherFocus.action, launcherFocus.role, launcherFocus.message = "Focus", "launcher", "STRIKE PACKAGE AWAY"
	Packets.packets.NukeCinematic.sendTo(launcherFocus, player)
	local defenderFocus = self:_base(session)
	defenderFocus.action, defenderFocus.role, defenderFocus.message = "Focus", "defender", "THIS NUKE WILL HIT YOU. DEFLECT IT."
	Packets.packets.NukeCinematic.sendTo(defenderFocus, defender)

	ECS.createEntity({
		Name = string.format("%s:NukeCooldown", model.Name),
		ScheduledTask = {delay = NUKE_COOLDOWN, elapsed = 0, kind = "NukeCooldown", tycoonEntity = entity, button = button},
	})

	task.delay(6, function()
		if self.ActiveSession ~= session or session.ended then return end
		local payload = self:_base(session)
		payload.action, payload.phase, payload.message = "Phase", "launch", "LAUNCH PLUME DETECTED"
		self:_send(payload)
	end)

	task.delay(ASCENT_TIME, function()
		if self.ActiveSession ~= session or session.ended then return end
		session.mashOpen = true
		local payload = self:_base(session)
		payload.action, payload.phase, payload.timeLeft = "MashStart", "mash", MASH_DURATION
		payload.launcherScore, payload.defenderScore = 0, 0
		payload.role, payload.message = "launcher", "DEFLECT THE STRIKE"
		Packets.packets.NukeCinematic.sendTo(payload, player)
		payload.role, payload.message = "defender", "DEFEND YOUR TYCOON"
		Packets.packets.NukeCinematic.sendTo(payload, defender)
	end)

	task.delay(TOTAL_FLIGHT_TIME - 15, function()
		if self.ActiveSession ~= session or session.ended then return end
		local payload = self:_base(session)
		payload.action, payload.phase, payload.message = "Phase", "terminal", "TERMINAL IMPACT SEQUENCE"
		self:_send(payload)
	end)

	task.delay(TOTAL_FLIGHT_TIME, function()
		if self.ActiveSession ~= session or session.ended then return end
		self:_finish(session, session.defenderState.score >= session.launcherState.score)
	end)
end

function NukeService:_attach(prompt: ProximityPrompt, entity: number)
	if self.PromptConnections[prompt] then return end
	self.PromptConnections[prompt] = prompt.Triggered:Connect(function(player)
		self:_start(entity, player, prompt)
	end)
	prompt.Destroying:Once(function()
		local connection = self.PromptConnections[prompt]
		if connection then connection:Disconnect(); self.PromptConnections[prompt] = nil end
	end)
end

function NukeService:_scan(model: Model, entity: number)
	for _, item in model:GetDescendants() do
		if item:IsA("ProximityPrompt") and item.Name == "Activate" and item:FindFirstAncestor("ButtonStand") then
			self:_attach(item, entity)
		end
	end
	if not self.ModelConnections[model] then
		self.ModelConnections[model] = model.DescendantAdded:Connect(function(item)
			if item:IsA("ProximityPrompt") and item.Name == "Activate" and item:FindFirstAncestor("ButtonStand") then
				self:_attach(item, entity)
			end
		end)
	end
end

function NukeService:Init()
	if self.Started then return end
	self.Started = true
	NetworkGuard.Listen(Packets.packets.NukeClickBatch, "NukeClickBatch", {
		Rate = 12,
		Burst = 18,
		Validate = function(payload)
			return type(payload) == "table"
				and type(payload.sessionId) == "string"
				and type(payload.count) == "number"
				and type(payload.clientWindow) == "number"
				and #payload.sessionId <= 80
				and payload.count >= 0 and payload.count <= 1000
				and payload.clientWindow >= 0.01 and payload.clientWindow <= 2
		end,
	}, function(payload, player)
		self:_click(payload, player)
	end)
	for _, entity in self.TycoonService.Entities do
		local model = Factory.getModel(entity)
		if model then self:_scan(model, entity) end
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = self.ActiveSession
		if session and (session.launcher == player or session.defender == player) then
			self:_finish(session, session.defender == player)
		end
	end)
end

return NukeService
