--!strict

-- Network adapter for the ECS nuke session. Session state is stored on the
-- launcher entity and advanced by NukeSystem.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
local Factory = require(ServerScriptService.Game.Tycoon.TycoonFactory)
local TycoonRuntime = require(ServerScriptService.Game.Tycoon.TycoonCoordinator)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)
local ValidatePromptRange = require(ServerScriptService.Game.Tycoon.Shared.ValidatePromptRange)
local Notify = require(ServerScriptService.Game.Tycoon.Shared.NotifyPlayer)
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
	elapsed: number,
	launchSent: boolean,
	mashSent: boolean,
	terminalSent: boolean,
}

local NukeService = {}
local BuildService: any
local Initialized = false

local function FindActiveSession(): (number?, Session?)
	for Entity, Data in ECS.world:query(ECS.Components.NukeSession) do
		if Data.Session and not Data.Session.ended then
			return Entity, Data.Session
		end
	end
	return nil, nil
end

local function FindTarget(LauncherEntity: number, Launcher: Player): (number?, Player?, Vector3?)
	local LauncherModel = Factory.GetModel(LauncherEntity)
	if not LauncherModel then
		return nil, nil, nil
	end
	local Source = LauncherModel:GetPivot().Position
	local BestEntity, BestPlayer, BestPosition, BestDistance
	for Entity, State in ECS.world:query(ECS.Components.TycoonState) do
		if Entity ~= LauncherEntity and State.active ~= false and State.owner and State.owner ~= Launcher then
			local Model = Factory.GetModel(Entity)
			if Model then
				local MainItems = Model:FindFirstChild("MainItems")
				local Target = MainItems and MainItems:FindFirstChild("Target", true)
				local Position = if Target and Target:IsA("BasePart")
					then Target.Position
					else Model:GetPivot().Position
				local Distance = (Position - Source).Magnitude
				if not BestDistance or Distance < BestDistance then
					BestEntity, BestPlayer, BestPosition, BestDistance = Entity, State.owner, Position, Distance
				end
			end
		end
	end
	return BestEntity, BestPlayer, BestPosition
end

local function GetDeathRange(Model: Model): number
	local _, Size = Model:GetBoundingBox()
	return math.max(MIN_DEATH_RANGE, math.max(Size.X, Size.Z) * DEATH_RANGE_MULTIPLIER)
end

local function BuildPayload(Current: Session): any
	return {
		sessionId = Current.id,
		launcherName = Current.launcher.Name,
		defenderName = Current.defender.Name,
		launcherUserId = tostring(Current.launcher.UserId),
		defenderUserId = tostring(Current.defender.UserId),
		sourcePosition = Current.sourcePosition,
		targetPosition = Current.targetPosition,
		deathRange = Current.deathRange,
	}
end

local function Send(Payload: any)
	Packets.packets.NukeCinematic.sendToAll(Payload)
end

local function ApplyImpact(TargetEntity: number, TargetPlayer: Player, Generation: number)
	local State = Factory.GetState(TargetEntity)
	local Owner = ECS.world:get(TargetEntity, ECS.Components.Owner)
	if
		not State
		or State.active == false
		or not Owner
		or Owner.player ~= TargetPlayer
		or Owner.generation ~= Generation
	then
		return
	end
	local Profile = ProfileManager.Profiles[TargetPlayer]
	if Profile then
		local Loss = math.floor(math.max(0, Profile.Data.Cash) * 0.25)
		if Loss > 0 then
			ProfileManager.AddCash(TargetPlayer, -Loss)
		end
	end
	TycoonRuntime.Cleanup(TargetEntity, BuildService)
end

local function Finish(Current: Session, DefenderWon: boolean)
	if Current.ended then
		return
	end
	Current.ended, Current.mashOpen = true, false
	ECS.world:remove(Current.launcherEntity, ECS.Components.NukeSession)
	local Winner = if DefenderWon then Current.defender else Current.launcher
	local Result = BuildPayload(Current)
	Result.action, Result.winnerName = "Result", Winner.Name
	Result.message = if DefenderWon then "DEFLECTION SUCCESSFUL" else "IMPACT AUTHORIZED"
	Result.launcherScore, Result.defenderScore = Current.launcherState.score, Current.defenderState.score
	Send(Result)
	local Impact = BuildPayload(Current)
	Impact.action = "Impact"
	Impact.message = if DefenderWon then "DEFLECTION SUCCESSFUL" else "IMPACT CONFIRMED"
	Send(Impact)
	if not DefenderWon then
		ECS.world:set(Current.defenderEntity, ECS.Components.NukeImpact, {
			Remaining = 10,
			TargetEntity = Current.defenderEntity,
			TargetPlayer = Current.defender,
			Generation = Current.defenderGeneration,
		})
	end
	ECS.world:set(Current.launcherEntity, ECS.Components.NukeEnd, { Remaining = 4, SessionId = Current.id })
end

local function HandleClick(Payload: any, Player: Player)
	local _, Current = FindActiveSession()
	if not Current or not Current.mashOpen or Payload.sessionId ~= Current.id then
		return
	end
	local Score = if Player == Current.launcher
		then Current.launcherState
		elseif Player == Current.defender then Current.defenderState
		else nil
	if not Score then
		return
	end
	local Count = math.clamp(math.floor(Payload.count), 0, MAX_BATCH_CLICKS)
	local Window = math.clamp(Payload.clientWindow, 0.05, 1)
	if Count <= 0 then
		return
	end
	local Now = os.clock()
	local Elapsed = math.max(Now - Score.lastAt, 0.05)
	local CPS = Count / math.min(Elapsed, Window)
	Score.cpsAverage, Score.lastAt = Score.cpsAverage * 0.58 + CPS * 0.42, Now
	if CPS > MAX_INSTANT_CPS or Score.cpsAverage > MAX_SUSTAINED_CPS then
		return
	end
	Score.score = math.clamp(Score.score + Count, 0, 100)
	local Packet = Packets.packets.NukeScore
	if Packet then
		Packet.sendToAll({
			sessionId = Current.id,
			launcherScore = Current.launcherState.score,
			defenderScore = Current.defenderState.score,
		})
	end
end

local function Start(LauncherEntity: number, Player: Player, Prompt: ProximityPrompt)
	local _, Existing = FindActiveSession()
	if Existing then
		Notify(Player, "info", "Another nuclear launch is already in progress.")
		return
	end
	local State = Factory.GetState(LauncherEntity)
	local Owner = ECS.world:get(LauncherEntity, ECS.Components.Owner)
	if not State or not Owner or Owner.player ~= Player then
		Notify(Player, "error", "Only the tycoon owner can launch this nuke.")
		return
	end
	if State.nukeCooldownReady == false then
		Notify(Player, "info", "The nuke launcher is recharging.")
		return
	end
	if not ValidatePromptRange(Player, Prompt) then
		Notify(Player, "info", "Move closer to launch the nuke.")
		return
	end
	local DefenderEntity, Defender, TargetPosition = FindTarget(LauncherEntity, Player)
	local Model = Factory.GetModel(LauncherEntity)
	local TargetModel = DefenderEntity and Factory.GetModel(DefenderEntity)
	if not DefenderEntity or not Defender or not TargetPosition or not Model or not TargetModel then
		Notify(Player, "info", "There is no occupied tycoon to target.")
		return
	end
	State.nukeCooldownReady = false
	ECS.world:set(LauncherEntity, ECS.Components.TycoonState, State)
	local Button = Prompt:FindFirstAncestorWhichIsA("BasePart")
	if Button then
		Button.BrickColor = BrickColor.new("Really red")
	end
	local TargetOwner = ECS.world:get(DefenderEntity, ECS.Components.Owner)
	local Current: Session = {
		id = HttpService:GenerateGUID(false),
		launcher = Player,
		defender = Defender,
		launcherEntity = LauncherEntity,
		defenderEntity = DefenderEntity,
		defenderGeneration = if TargetOwner then TargetOwner.generation or 0 else 0,
		sourcePosition = if Button then Button.Position else Model:GetPivot().Position,
		targetPosition = TargetPosition,
		deathRange = GetDeathRange(TargetModel),
		launcherState = { lastAt = os.clock(), cpsAverage = 0, score = 0 },
		defenderState = { lastAt = os.clock(), cpsAverage = 0, score = 0 },
		mashOpen = false,
		ended = false,
		elapsed = 0,
		launchSent = false,
		mashSent = false,
		terminalSent = false,
	}
	local Warning = BuildPayload(Current)
	Warning.action, Warning.phase, Warning.message = "Warning", "warning", "NUCLEAR INBOUND"
	Warning.distance, Warning.timeLeft = (Current.sourcePosition - TargetPosition).Magnitude, TOTAL_FLIGHT_TIME
	Send(Warning)
	local LauncherFocus = BuildPayload(Current)
	LauncherFocus.action, LauncherFocus.role, LauncherFocus.message = "Focus", "launcher", "STRIKE PACKAGE AWAY"
	Packets.packets.NukeCinematic.sendTo(LauncherFocus, Player)
	local DefenderFocus = BuildPayload(Current)
	DefenderFocus.action, DefenderFocus.role, DefenderFocus.message =
		"Focus", "defender", "THIS NUKE WILL HIT YOU. DEFLECT IT."
	Packets.packets.NukeCinematic.sendTo(DefenderFocus, Defender)
	ECS.world:set(LauncherEntity, ECS.Components.NukeCooldown, { Remaining = NUKE_COOLDOWN, Button = Button })
	ECS.world:set(LauncherEntity, ECS.Components.NukeSession, { Session = Current })
end

local function Advance(Entity: number, DeltaTime: number)
	local Data = ECS.world:get(Entity, ECS.Components.NukeSession)
	local Current = Data and Data.Session
	if not Current or Current.ended then
		ECS.world:remove(Entity, ECS.Components.NukeSession)
		return
	end
	Current.elapsed += DeltaTime
	if not Current.launchSent and Current.elapsed >= 6 then
		Current.launchSent = true
		local Payload = BuildPayload(Current)
		Payload.action, Payload.phase, Payload.message = "Phase", "launch", "LAUNCH PLUME DETECTED"
		Send(Payload)
	end
	if not Current.mashSent and Current.elapsed >= ASCENT_TIME then
		Current.mashSent, Current.mashOpen = true, true
		local Payload = BuildPayload(Current)
		Payload.action, Payload.phase, Payload.timeLeft = "MashStart", "mash", MASH_DURATION
		Payload.launcherScore, Payload.defenderScore = 0, 0
		Payload.role, Payload.message = "launcher", "DEFLECT THE STRIKE"
		Packets.packets.NukeCinematic.sendTo(Payload, Current.launcher)
		Payload.role, Payload.message = "defender", "DEFEND YOUR TYCOON"
		Packets.packets.NukeCinematic.sendTo(Payload, Current.defender)
	end
	if not Current.terminalSent and Current.elapsed >= TOTAL_FLIGHT_TIME - 15 then
		Current.terminalSent = true
		local Payload = BuildPayload(Current)
		Payload.action, Payload.phase, Payload.message = "Phase", "terminal", "TERMINAL IMPACT SEQUENCE"
		Send(Payload)
	end
	if Current.elapsed >= TOTAL_FLIGHT_TIME then
		Finish(Current, Current.defenderState.score >= Current.launcherState.score)
	end
end

function NukeService.ProcessImpactActive(TargetEntity: number, TargetPlayer: Player, Generation: number)
	ApplyImpact(TargetEntity, TargetPlayer, Generation)
end

function NukeService.SendEndActive(SessionId: string)
	Send({ action = "End", sessionId = SessionId })
end

function NukeService.AdvanceActive(Entity: number, DeltaTime: number)
	Advance(Entity, DeltaTime)
end

function NukeService.StartActive(LauncherEntity: number, Player: Player, Prompt: ProximityPrompt)
	Start(LauncherEntity, Player, Prompt)
end

function NukeService.Init(BuildServiceValue: any)
	if Initialized then
		return
	end
	BuildService = BuildServiceValue
	NetworkGuard.Listen(Packets.packets.NukeClickBatch, "NukeClickBatch", {
		Rate = 12,
		Burst = 18,
		Validate = function(Payload)
			return type(Payload) == "table"
				and type(Payload.sessionId) == "string"
				and type(Payload.count) == "number"
				and type(Payload.clientWindow) == "number"
				and #Payload.sessionId <= 80
				and Payload.count >= 0
				and Payload.count <= 1000
				and Payload.clientWindow >= 0.01
				and Payload.clientWindow <= 2
		end,
	}, HandleClick)
	Observers.observePlayer(function(Player: Player)
		return function()
			local _, Current = FindActiveSession()
			if Current and (Current.launcher == Player or Current.defender == Player) then
				Finish(Current, Current.defender == Player)
			end
		end
	end)
	Initialized = true
end

return NukeService
