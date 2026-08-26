--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Packets = require(ReplicatedStorage.Network.Packets)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)

local Remotes = ReplicatedStorage.Remotes
local NuclearFrame = ServerStorage.UI:FindFirstChild("NuclearFrame") :: Frame?
local FrozenMovementByHumanoid: { [Humanoid]: { WalkSpeed: number, JumpPower: number } } = {}

type IPlayerService = {
	HasActivated: (self: IPlayerService, player: Player) -> boolean,
	ActivateRocket: (self: IPlayerService, player: Player, value: boolean) -> (),
}

type SessionPlayerState = {
	lastAt: number,
	cpsAverage: number,
	score: number,
}

type NukeSession = {
	id: string,
	launcher: Player,
	defender: Player?,
	launcherState: SessionPlayerState,
	defenderState: SessionPlayerState,
	mashOpen: boolean,
	ended: boolean,
}

type RocketModule = {
	Rocket: Model,
	Player: Player,
	PlayerService: IPlayerService,
	Audios: Folder,
	Registry: { [Instance]: any },
	OuterRocket: BasePart,
	Target: BasePart?,
	TargetTycoon: any?,
	TargetPlayer: Player?,
	Impact: BasePart,
	Explosion: BasePart,
	Fire: Attachment?,
	SmokeParticle: ParticleEmitter?,
	Highlight: Highlight?,
	LaunchLight: PointLight?,
	_initConnection: RBXScriptConnection?,
	Init: (self: RocketModule) -> (),
	StartRocket: (self: RocketModule) -> (),
}

local DEATH_RANGE_MULTIPLIER = 6
local MIN_DEATH_RANGE = 650
local ASCENT_TIME = 20
local DESCENT_TIME = 30
local TOTAL_FLIGHT_TIME = ASCENT_TIME + DESCENT_TIME
local MASH_START_TIME = ASCENT_TIME
local MASH_DURATION = TOTAL_FLIGHT_TIME - MASH_START_TIME
local MAX_BATCH_CLICKS = 12
local MAX_INSTANT_CPS = 32
local MAX_SUSTAINED_CPS = 24

local activeSessions: { [string]: NukeSession } = {}
local clickListenerStarted = false

local warningQuotes = {
	"NUCLEAR INBOUND",
	"IMPACT VECTOR CONFIRMED",
	"THERMAL SIGNATURE SPIKING",
	"MISSILE ASCENT DETECTED",
	"REENTRY WINDOW OPEN",
	"TARGET LOCK IS STABLE",
	"SHOCKWAVE RANGE EXPANDING",
	"DEFLECTION SYSTEM ARMED",
	"KEEP CLICKING",
	"DON'T LET THEM WIN",
	"PRESSURE RISING",
	"YOU ARE ALMOST THERE",
	"THE SKY IS BURNING",
	"FINAL IMPACT SOLUTION",
	"ARMOUR FIELD STRAINING",
	"COUNTERFORCE BUILDING",
	"MISSILE PLUME VISIBLE",
	"REENTRY BURN CONFIRMED",
	"BLAST FRONT CALCULATED",
	"STAND YOUR GROUND",
	"BREACH RISK CRITICAL",
	"DEFLECTOR CHARGE CLIMBING",
	"COUNTERMEASURE ONLINE",
	"DO NOT STOP",
	"THEIR LAUNCH IS WEAKENING",
	"YOUR FIELD IS HOLDING",
	"TARGETING COMPUTER SCREAMING",
	"IMPACT IN SECONDS",
	"CORE PRESSURE PEAKING",
	"KEEP THE ARMOUR ALIVE",
	"MISSILE BODY HEATING",
	"DEFENSE GRID PULSING",
	"THE STRIKE CAN BE TURNED",
	"PANIC PROTOCOL ACTIVE",
	"NUCLEAR BLOOM IMMINENT",
	"OVERPRESSURE WARNING",
	"YOU CAN STILL WIN",
	"FORCE THE DEFLECTION",
	"CLICK THROUGH THE IMPACT",
	"HEAT WAVE FRONT DETECTED",
	"THE BUTTON IS THE SHIELD",
	"LAST CHANCE",
	"THE COUNTDOWN IS LYING",
	"BREAK THEIR LOCK",
	"MISSILE IS COMMITTED",
	"ARMOUR CORE NEEDS INPUT",
	"DEFLECTION RACE ACTIVE",
	"DO NOT LET GO",
	"THE TARGET IS LIT",
	"FINAL SHOCKWAVE PREP",
}

local leaveQuotes = {
	"left during a nuclear strike. Tactical translation: too scared.",
	"vanished before impact. The missile took that personally.",
	"abandoned their tycoon during reentry. Cowardice detected.",
	"left the blast zone, but the blast zone did not leave them.",
}

local function systemMessage(message: string)
	Packets.packets.GameEvent.sendToAll({
		["type"] = "SystemMessage",
		message = `[Game]: <b><font color='#ff7a32'>{message}</font></b>`,
	})
end

local function destroyLater(instance: Instance, lifetime: number)
	task.delay(lifetime, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

local function assertInstance(value: Instance?, expectedClass: string, label: string): Instance
	if not value then
		error(`[RocketModule] Missing {label}`, 2)
	end

	if not value:IsA(expectedClass) then
		error(`[RocketModule] {label} expected {expectedClass}, got {value.ClassName}`, 2)
	end

	return value
end

local function playSound(folder: Folder, name: string, volume: number?)
	local sound = folder:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		sound.Volume = math.min(volume or sound.Volume, 0.65)
		sound:Play()
	end
end

local function stopAlarmSounds(folder: Folder)
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("Sound") then
			local name = descendant.Name
			if name ~= "Explosion" and name ~= "Shockwave" then
				descendant:Stop()
			end
		end
	end
end

local function easeInOut(value: number): number
	return if value < 0.5 then 4 * value ^ 3 else 1 - ((-2 * value + 2) ^ 3) / 2
end

local function easeOutExpo(value: number): number
	return if value >= 1 then 1 else 1 - 2 ^ (-10 * value)
end

local function cubicBezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: number): Vector3
	local ab = a:Lerp(b, t)
	local bc = b:Lerp(c, t)
	local cd = c:Lerp(d, t)
	local abc = ab:Lerp(bc, t)
	local bcd = bc:Lerp(cd, t)
	return abc:Lerp(bcd, t)
end

local function sendCinematicTo(player: Player?, payload)
	if player and player.Parent then
		Packets.packets.NukeCinematic.sendTo(payload, player)
	end
end

local function sendCinematicAll(payload)
	Packets.packets.NukeCinematic.sendToAll(payload)
end

local function setFrozen(player: Player?, frozen: boolean)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if frozen then
		if not FrozenMovementByHumanoid[humanoid] then
			FrozenMovementByHumanoid[humanoid] = {
				WalkSpeed = humanoid.WalkSpeed,
				JumpPower = humanoid.JumpPower,
			}
		end
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	else
		local savedMovement = FrozenMovementByHumanoid[humanoid]
		humanoid.WalkSpeed = if savedMovement then savedMovement.WalkSpeed else 16
		humanoid.JumpPower = if savedMovement then savedMovement.JumpPower else 50
		FrozenMovementByHumanoid[humanoid] = nil
	end
end

local function createShockRing(position: Vector3, color: Color3, radius: number, duration: number)
	local ring = Instance.new("Part")
	ring.Name = "NukeShockwaveRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.25, 8, 8)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.25, radius, radius),
		Transparency = 1,
	}):Play()
	destroyLater(ring, duration + 0.2)
end

local function spawnAnomalies(targetPosition: Vector3)
	for index = 1, 7 do
		task.delay(index * 0.32, function()
			local angle = index * 2.399
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (40 + index * 22)
			createShockRing(
				targetPosition + offset + Vector3.new(0, 1.5, 0),
				Color3.fromRGB(255, 120, 42),
				70 + index * 18,
				1.1
			)
		end)
	end
end

local function payloadBase(
	session: NukeSession,
	sourcePosition: Vector3?,
	targetPosition: Vector3?,
	deathRange: number?
)
	local defender = session.defender
	return {
		sessionId = session.id,
		launcherName = session.launcher.Name,
		defenderName = if defender then defender.Name else nil,
		launcherUserId = tostring(session.launcher.UserId),
		defenderUserId = if defender then tostring(defender.UserId) else nil,
		sourcePosition = sourcePosition,
		targetPosition = targetPosition,
		deathRange = deathRange,
	}
end

local function getTycoonRadius(targetTycoon): number
	if not targetTycoon or not targetTycoon.Model then
		return MIN_DEATH_RANGE
	end

	local _, size = targetTycoon.Model:GetBoundingBox()
	return math.max(MIN_DEATH_RANGE, math.max(size.X, size.Z) * DEATH_RANGE_MULTIPLIER)
end

local function reduceCash(player: Player, percent: number)
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return
	end

	local loss = math.floor(math.max(0, profile.Data.Cash) * percent)
	if loss > 0 then
		ProfileManager.AddCash(player, -loss)
	end
end

local function resetTycoon(targetTycoon, targetPlayer: Player?)
	if targetPlayer and targetPlayer.Parent then
		reduceCash(targetPlayer, 0.25)
	end

	task.delay(10, function()
		if targetTycoon and targetTycoon.Cleanup then
			if targetPlayer and targetPlayer.Parent and targetTycoon._ClearSavedConstruction then
				targetTycoon:_ClearSavedConstruction(targetPlayer)
			end
			targetTycoon:Cleanup()
		end
	end)
end

local function punishAutoClicker(player: Player)
	systemMessage(`{player.Name} was kicked for impossible CPS during nuclear deflection.`)
	player:Kick("Fast CPS detected during nuclear deflection.")
end

local function broadcastScore(session: NukeSession)
	sendCinematicAll({
		action = "Score",
		sessionId = session.id,
		launcherScore = session.launcherState.score,
		defenderScore = session.defenderState.score,
	})
end

local function registerClickBatch(payload, player: Player?)
	if not player then
		return
	end

	local session = activeSessions[payload.sessionId]
	if not session or not session.mashOpen or session.ended then
		return
	end

	local state: SessionPlayerState?
	if player == session.launcher then
		state = session.launcherState
	elseif player == session.defender then
		state = session.defenderState
	end

	if not state then
		return
	end

	local now = os.clock()
	local elapsed = math.max(now - state.lastAt, 0.05)
	local count = math.floor(payload.count)
	local clientWindow = math.max(payload.clientWindow, 0.05)
	local instantCps = count / math.min(elapsed, clientWindow)
	state.cpsAverage = state.cpsAverage * 0.58 + instantCps * 0.42
	state.lastAt = now

	if count > MAX_BATCH_CLICKS or instantCps > MAX_INSTANT_CPS or state.cpsAverage > MAX_SUSTAINED_CPS then
		session.ended = true
		activeSessions[session.id] = nil
		punishAutoClicker(player)
		return
	end

	state.score = math.clamp(state.score + count, 0, 100)
	broadcastScore(session)
end

local function startClickListener()
	if clickListenerStarted then
		return
	end

	clickListenerStarted = true
	Packets.packets.NukeClickBatch.listen(registerClickBatch)
	Players.PlayerRemoving:Connect(function(player)
		for _, session in pairs(activeSessions) do
			if session.defender == player and not session.ended then
				systemMessage(`{player.Name} {leaveQuotes[math.random(1, #leaveQuotes)]}`)
			end
		end
	end)
end

local RocketModuleClass = {}
RocketModuleClass.__index = RocketModuleClass

function RocketModuleClass.new(
	rocket: Model,
	player: Player,
	playerService: IPlayerService,
	audios: Folder,
	registry: { [Instance]: any }
): RocketModule
	startClickListener()

	local outerRocket = assertInstance(rocket:FindFirstChild("OuterRocket"), "MeshPart", "OuterRocket") :: BasePart
	local nozzle = rocket:FindFirstChild("Nozzle")
	local smokeParticle: ParticleEmitter? = nil
	local fire: Attachment? = nil
	if nozzle then
		local smoke = nozzle:FindFirstChild("Smoke")
		fire = nozzle:FindFirstChild("Fire") :: Attachment?
		smokeParticle = smoke and smoke:FindFirstChildOfClass("ParticleEmitter")
	end

	return setmetatable({
		Rocket = rocket,
		Player = player,
		PlayerService = playerService,
		Audios = audios,
		Registry = registry,
		OuterRocket = outerRocket,
		Impact = ReplicatedStorage.Assets.Workspace.Rocket.Impact,
		Explosion = ReplicatedStorage.Assets.Workspace.Rocket.Explosion,
		Fire = fire,
		SmokeParticle = smokeParticle,
		_initConnection = nil,
	}, RocketModuleClass) :: any
end

function RocketModuleClass:_findTarget(argument: string): boolean
	local tycoonsFolder = workspace:FindFirstChild("Tycoons")
	local tycoonModel = tycoonsFolder and tycoonsFolder:FindFirstChild(argument)
	if not tycoonModel or not tycoonModel:IsA("Model") then
		return false
	end

	local targetTycoon = self.Registry[tycoonModel]
	local owner = targetTycoon and targetTycoon.Owner
	if not owner or owner == self.Player then
		return false
	end

	local mainItems = tycoonModel:FindFirstChild("MainItems")
	local target = mainItems and mainItems:FindFirstChild("Target")
	if not target or not target:IsA("BasePart") then
		return false
	end

	self.Target = target
	self.TargetTycoon = targetTycoon
	self.TargetPlayer = owner :: Player
	return true
end

function RocketModuleClass:_setEnginePower(power: number)
	if self.SmokeParticle then
		self.SmokeParticle.Enabled = power > 0
		self.SmokeParticle.Rate = 20 + power * 90
	end

	if self.Fire then
		for _, child in self.Fire:GetChildren() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = power > 0
				child.Rate = 25 + power * 160
				child.Size = NumberSequence.new(1 + power * 18)
			end
		end
	end
end

function RocketModuleClass:_animateRocket(session: NukeSession, sourcePosition: Vector3, targetPosition: Vector3)
	local rocket = self.OuterRocket
	local startTime = os.clock()
	local skyApex = sourcePosition + Vector3.new(0, 1280, 0)
	local reentryStart = targetPosition + Vector3.new(420, 1420, -470)
	local strikeStart = targetPosition + Vector3.new(185, 1220, -285)
	local strikeControlA = targetPosition + Vector3.new(85, 920, -135)
	local strikeControlB = targetPosition + Vector3.new(18, 330, -38)

	local connection: RBXScriptConnection?
	connection = RunService.Heartbeat:Connect(function()
		if not rocket.Parent or session.ended then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local elapsed = os.clock() - startTime
		local position: Vector3
		local nextPosition: Vector3
		if elapsed < 4 then
			local t = easeInOut(elapsed / 4)
			position = sourcePosition:Lerp(sourcePosition + Vector3.new(0, 82, 0), t)
			nextPosition = sourcePosition:Lerp(sourcePosition + Vector3.new(0, 90, 0), math.min(t + 0.02, 1))
			self:_setEnginePower(0.25 + t * 0.55)
		elseif elapsed < 8 then
			local t = (math.clamp((elapsed - 4) / 4, 0, 1)) ^ 0.42
			position = (sourcePosition + Vector3.new(0, 82, 0)):Lerp(skyApex, t)
			nextPosition = (sourcePosition + Vector3.new(0, 82, 0)):Lerp(skyApex, math.min(t + 0.025, 1))
			self:_setEnginePower(1)
		elseif elapsed < ASCENT_TIME then
			local t = easeInOut((elapsed - 8) / (ASCENT_TIME - 8))
			position = skyApex:Lerp(reentryStart, t)
			nextPosition = skyApex:Lerp(reentryStart, math.min(t + 0.02, 1))
			self:_setEnginePower(0.85)
		else
			local descentElapsed = elapsed - ASCENT_TIME
			if descentElapsed < DESCENT_TIME - 4 then
				local t = easeInOut(math.clamp(descentElapsed / (DESCENT_TIME - 4), 0, 1))
				position = reentryStart:Lerp(strikeStart, t)
				nextPosition = reentryStart:Lerp(strikeStart, math.min(t + 0.025, 1))
			else
				local t = math.clamp((descentElapsed - (DESCENT_TIME - 4)) / 4, 0, 1)
				local strikeT = t ^ 2.35
				position = cubicBezier(strikeStart, strikeControlA, strikeControlB, targetPosition, strikeT)
				nextPosition = cubicBezier(
					strikeStart,
					strikeControlA,
					strikeControlB,
					targetPosition,
					math.min(strikeT + 0.055, 1)
				)
			end
			self:_setEnginePower(1.55)
		end

		local direction = nextPosition - position
		if direction.Magnitude > 0.01 then
			rocket.CFrame = CFrame.lookAt(position, position + direction.Unit) * CFrame.Angles(math.rad(90), 0, 0)
		else
			rocket.CFrame = CFrame.new(position)
		end
	end)
end

function RocketModuleClass:_detonate(deflected: boolean, session: NukeSession)
	local target = self.Target
	if not target then
		return
	end

	createShockRing(target.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 255, 255), 1300, 2.3)
	createShockRing(target.Position + Vector3.new(0, 5, 0), Color3.fromRGB(255, 118, 32), 900, 1.55)

	local explosion = self.Explosion:Clone()
	explosion.Parent = workspace
	explosion:PivotTo(target.CFrame)
	for _, descendant in explosion:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant:Emit(12)
		end
	end
	destroyLater(explosion, 8)

	local impact = self.Impact:Clone()
	impact.Parent = workspace
	impact:PivotTo(target.CFrame)
	for _, descendant in impact:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant:Emit(18)
		end
	end
	destroyLater(impact, 15)

	playSound(self.Audios, "Explosion", 0.48)
	playSound(self.Audios, "Shockwave", 0.55)

	sendCinematicAll({
		action = "Impact",
		sessionId = session.id,
		targetPosition = target.Position,
		message = if deflected then "DEFLECTION SUCCESSFUL" else "IMPACT CONFIRMED",
	})

	if not deflected then
		resetTycoon(self.TargetTycoon, self.TargetPlayer)
	end

	if self.OuterRocket.Parent then
		self.OuterRocket:Destroy()
	end
	if self.Rocket.Parent then
		self.Rocket:Destroy()
	end

	stopAlarmSounds(self.Audios)
end

function RocketModuleClass:_startMeltdownLook()
	local highlight = Instance.new("Highlight")
	highlight.Name = "NukeMeltdownHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 80, 18)
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 232, 190)
	highlight.OutlineTransparency = 0.22
	highlight.Parent = self.Rocket
	self.Highlight = highlight

	local light = Instance.new("PointLight")
	light.Name = "NukeLaunchGlow"
	light.Color = Color3.fromRGB(255, 92, 26)
	light.Brightness = 0
	light.Range = 0
	light.Parent = self.OuterRocket
	self.LaunchLight = light

	TweenService:Create(highlight, TweenInfo.new(5.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		FillTransparency = 0.24,
		OutlineTransparency = 0,
	}):Play()
	TweenService:Create(light, TweenInfo.new(5.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		Brightness = 7,
		Range = 72,
	}):Play()
end

function RocketModuleClass:StartRocket()
	local target = self.Target
	local defender = self.TargetPlayer
	if not target or not defender then
		return
	end

	self.Rocket.PrimaryPart = self.OuterRocket
	local sourcePosition = self.OuterRocket.Position
	local targetPosition = target.Position
	local distance = (sourcePosition - targetPosition).Magnitude
	local deathRange = getTycoonRadius(self.TargetTycoon)
	local session: NukeSession = {
		id = `{self.Player.UserId}-{math.floor(os.clock() * 1000)}-{math.random(1000, 9999)}`,
		launcher = self.Player,
		defender = defender,
		launcherState = { lastAt = os.clock(), cpsAverage = 0, score = 0 },
		defenderState = { lastAt = os.clock(), cpsAverage = 0, score = 0 },
		mashOpen = false,
		ended = false,
	}
	activeSessions[session.id] = session

	local warningPayload = payloadBase(session, sourcePosition, targetPosition, deathRange)
	warningPayload.action = "Warning"
	warningPayload.phase = "warning"
	warningPayload.message = "NUCLEAR INBOUND"
	warningPayload.distance = distance
	warningPayload.timeLeft = TOTAL_FLIGHT_TIME
	sendCinematicAll(warningPayload)

	local launcherPayload = payloadBase(session, sourcePosition, targetPosition, deathRange)
	launcherPayload.action = "Focus"
	launcherPayload.role = "launcher"
	launcherPayload.message = "STRIKE PACKAGE AWAY"
	sendCinematicTo(self.Player, launcherPayload)

	local defenderPayload = payloadBase(session, sourcePosition, targetPosition, deathRange)
	defenderPayload.action = "Focus"
	defenderPayload.role = "defender"
	defenderPayload.message = "THIS NUKE WILL HIT YOU. DEFLECT IT."
	sendCinematicTo(defender, defenderPayload)

	systemMessage(`{self.Player.Name} launched a Nuclear Missile on {defender.Name}'s Tycoon.`)
	playSound(self.Audios, "Evacuation", 0.35)
	playSound(self.Audios, "Critical", 0.32)
	spawnAnomalies(sourcePosition)
	self:_startMeltdownLook()
	self:_animateRocket(session, sourcePosition, targetPosition)

	task.delay(6, function()
		if session.ended then
			return
		end
		playSound(self.Audios, "Alarm3", 0.38)
		local payload = payloadBase(session, sourcePosition, targetPosition, deathRange)
		payload.action = "Phase"
		payload.phase = "launch"
		payload.message = "LAUNCH PLUME DETECTED"
		sendCinematicAll(payload)
	end)

	task.delay(ASCENT_TIME, function()
		if session.ended then
			return
		end
		local payload = payloadBase(session, sourcePosition, targetPosition, deathRange)
		payload.action = "Phase"
		payload.phase = "reentry"
		payload.message = "REENTRY BURN CONFIRMED"
		sendCinematicAll(payload)
	end)

	task.delay(MASH_START_TIME, function()
		if session.ended then
			return
		end
		session.mashOpen = true
		setFrozen(self.Player, true)
		setFrozen(defender, true)
		spawnAnomalies(targetPosition)
		local launchMashPayload = payloadBase(session, sourcePosition, targetPosition, deathRange)
		launchMashPayload.action = "MashStart"
		launchMashPayload.role = "launcher"
		launchMashPayload.message = warningQuotes[math.random(1, #warningQuotes)]
		launchMashPayload.timeLeft = MASH_DURATION
		launchMashPayload.launcherScore = 0
		launchMashPayload.defenderScore = 0
		sendCinematicTo(self.Player, launchMashPayload)

		local defendMashPayload = payloadBase(session, sourcePosition, targetPosition, deathRange)
		defendMashPayload.action = "MashStart"
		defendMashPayload.role = "defender"
		defendMashPayload.message = warningQuotes[math.random(1, #warningQuotes)]
		defendMashPayload.timeLeft = MASH_DURATION
		defendMashPayload.launcherScore = 0
		defendMashPayload.defenderScore = 0
		sendCinematicTo(defender, defendMashPayload)
	end)

	task.delay(TOTAL_FLIGHT_TIME - 15, function()
		if session.ended then
			return
		end
		local payload = payloadBase(session, sourcePosition, targetPosition, deathRange)
		payload.action = "Phase"
		payload.phase = "terminal"
		payload.message = "TERMINAL IMPACT SEQUENCE"
		sendCinematicAll(payload)
	end)

	task.delay(TOTAL_FLIGHT_TIME, function()
		if session.ended then
			return
		end

		session.ended = true
		session.mashOpen = false
		activeSessions[session.id] = nil
		setFrozen(self.Player, false)
		setFrozen(defender, false)

		local defenderWins = session.defenderState.score >= session.launcherState.score
		local winnerName = if defenderWins then defender.Name else self.Player.Name
		self:_detonate(defenderWins, session)

		sendCinematicAll({
			action = "Result",
			sessionId = session.id,
			winnerName = winnerName,
			message = if defenderWins
				then `{defender.Name} SUCCESSFULLY DEFLECTED THE NUCLEAR STRIKE.`
				else `{defender.Name} FAILED DEFLECTION. TYCOON DESTRUCTION AUTHORIZED.`,
			launcherScore = session.launcherState.score,
			defenderScore = session.defenderState.score,
		})

		if defenderWins then
			systemMessage(`{defender.Name} successfully deflected {self.Player.Name}'s nuclear strike.`)
		else
			systemMessage(
				`{defender.Name} failed to deflect {self.Player.Name}'s nuclear strike. Tycoon reset in 10 seconds.`
			)
		end

		task.delay(4, function()
			sendCinematicAll({ action = "End", sessionId = session.id })
		end)
	end)
end

function RocketModuleClass:Init()
	if not self.PlayerService:HasActivated(self.Player) then
		return
	end

	local playerGui = self.Player:FindFirstChildOfClass("PlayerGui")
	local mainInterface = playerGui and playerGui:FindFirstChild("MainInterface")
	if NuclearFrame and mainInterface then
		local panel = NuclearFrame:Clone()
		panel.Parent = mainInterface
	end

	if self._initConnection then
		self._initConnection:Disconnect()
	end

	self._initConnection = Packets.packets.NukeTarget.listen(function(payload, player: Player?)
		if player ~= self.Player then
			return
		end

		local argument = payload.target
		if typeof(argument) ~= "string" or #argument > 32 then
			warn(`[Rocket] {player and player.Name} sent malformed target identifier`)
			return
		end

		if self:_findTarget(argument) then
			if self._initConnection then
				self._initConnection:Disconnect()
				self._initConnection = nil
			end
			self:StartRocket()
		else
			warn(`[Rocket] {player and player.Name} sent invalid target: {argument}`)
		end
	end) or {
		Disconnect = function() end,
	}
end

return RocketModuleClass
