

--!strict
--[[
	@class NPCData

	@desc
	Creates and manages individual NPC controllers.
	Handles state machine setup, death/respawn pooling, and
	health-changed threat reactions.
]]

--// Services

const PathfindingService = game:GetService("PathfindingService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerStorage = game:GetService("ServerStorage")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const NPCRegistry = require(game:GetService("ServerScriptService").AI.NPCRegistry)
const Config = require(script.Parent.Config)
const AvoidFrontBlockState = require(script.Parent.Parent.States.AvoidFrontBlockState)
const DeadState = require(script.Parent.Parent.States.DeadState)
const IdleState = require(script.Parent.Parent.States.IdleState)
const ObservePlayerState = require(script.Parent.Parent.States.ObservePlayerState)
const PatrolState = require(script.Parent.Parent.States.PatrolState)
const Dialogue = require(script.Parent.Parent.Services.Dialogue)
const Speech = require(script.Parent.Parent.Services.Speech)
const StateMachine = require(script.Parent.StateMachine)
const Types = require(script.Parent.Types)
const WorldQuery = require(script.Parent.Parent.Services.WorldQuery)

--// Types

type AIContext = Types.AIContext
type StateMachineController = StateMachine.StateMachineController

--// Constants

const ClonesFolder = ServerStorage:WaitForChild("Clones")
const NPCFolder = workspace:WaitForChild("NPCs")

--// Module

local NPCData = {}
NPCData.__index = NPCData

export type NPCController = AIContext & {
        StateMachine: StateMachineController,
        _StartStateLoop: (self: NPCController) -> (),
        _ConnectDied: (self: NPCController) -> (),
        _ConnectHealthChanged: (self: NPCController) -> (),
        CharacterPool: (self: NPCController) -> (),
}

type NPCControllerMutable = AIContext & {
        StateMachine: StateMachineController?,
        _StartStateLoop: (self: NPCController) -> (),
        _ConnectDied: (self: NPCController) -> (),
        _ConnectHealthChanged: (self: NPCController) -> (),
        CharacterPool: (self: NPCController) -> (),
}

local function createPath(): Path
	return PathfindingService:CreatePath(Config.Path)
end

local function getStartingDisposition(): Types.Disposition
	if math.random() < 0.5 then
		return "Happy"
	end

	return "Normal"
end

function NPCData.new(npc: Model): NPCController
	local humanoid = npc:WaitForChild("Humanoid") :: Humanoid
	local primaryPart = WorldQuery.GetRootPart(npc)

	local self : any = setmetatable({
		NPC = npc,
		Humanoid = humanoid,
		Name = npc.Name,
		PrimaryPart = primaryPart,
		StartPivot = primaryPart:GetPivot(),
		Goal = npc:FindFirstChild("Goal") :: StringValue?,
		Path = createPath(),
		DiedConnection = nil,
		HealthConnection = nil,
		StateThreadRunning = false,
		LastHealth = humanoid.Health,
		LastObservationTime = 0,
		LastDamageSpeechTime = 0,
		IdleUntil = 0,
		AvoidUntil = 0,
		AvoidPauseUntil = 0,
		AbrasiveUntil = 0,
		IgnoreObservationUntil = 0,
		AvoidDirection = 1,
		GoalDirection = "ToGoal",
		Disposition = getStartingDisposition(),
		LastInteractionUserId = 0,
		LastInteractionTime = 0,
		RepeatInteractionCount = 0,
		LastSpokenLine = "",
		ObservationTarget = nil,
		ObservationSecondaryTarget = nil,
		ObservationLine = nil,
		ObservationLookPosition = nil,
		ObservationHoldDuration = Config.ObservationDuration,
		ObservationShouldWave = false,
		ObservationShouldAvoidAfter = false,
		ObservationAvoidMode = "Sidestep",
		AvoidLookTarget = nil,
		AvoidTarget = nil,
		AvoidMode = "Sidestep",
                Config = Config,
                ECSEntity = nil,
                StateMachine = nil,
        }, NPCData)

	self.Humanoid.WalkSpeed = Config.DefaultWalkSpeed
	self.PrimaryPart:SetNetworkOwner(nil)

	local stateMachine = StateMachine.new(self :: AIContext)
	self.StateMachine = stateMachine
	stateMachine:RegisterState(PatrolState)
	stateMachine:RegisterState(ObservePlayerState)
	stateMachine:RegisterState(AvoidFrontBlockState)
	stateMachine:RegisterState(IdleState)
	stateMachine:RegisterState(DeadState)
	stateMachine:SetState("Patrol")

	self:_ConnectDied()
	self:_ConnectHealthChanged()
	self:_StartStateLoop()

	return self  :: NPCController
end

function NPCData:_StartStateLoop()
	if self.StateThreadRunning then
		return
        end

        self.StateThreadRunning = true
        self.ECSEntity = ECS.createEntity({
                Name = `{self.Name}:NPCUpdate`,
                Model = self.NPC,
                NPCUpdate = {
                        npcEntity = 0,
                        interval = self.Config.UpdateInterval,
                        elapsed = 0,
                },
        })
        NPCRegistry.Register(self.ECSEntity, self)
        local Update = ECS.get(self.ECSEntity, "NPCUpdate")
        Update.npcEntity = self.ECSEntity
        ECS.set(self.ECSEntity, "NPCUpdate", Update)
end

function NPCData:_ConnectDied()
	local stateMachine = self.StateMachine
	if not stateMachine then
		return
	end

	if self.DiedConnection then
		self.DiedConnection:Disconnect()
		self.DiedConnection = nil
	end

	if self.HealthConnection then
		self.HealthConnection:Disconnect()
		self.HealthConnection = nil
	end

        self.DiedConnection = self.Humanoid.Died:Connect(function()
                stateMachine:SetState("Dead")
                ECS.createEntity({
                        Name = `{self.Name}:NPCRespawn`,
                        ScheduledTask = {
                                delay = self.Config.RespawnDelay,
                                elapsed = 0,
                                kind = "NPCRespawn",
                                npcEntity = self.ECSEntity,
                        },
                })
        end)
end

function NPCData:_ConnectHealthChanged()
	if self.HealthConnection then
		self.HealthConnection:Disconnect()
		self.HealthConnection = nil
	end

	self.LastHealth = self.Humanoid.Health
	self.HealthConnection = self.Humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth < self.LastHealth and newHealth > 0 then
			local now = os.clock()
			if now - self.LastDamageSpeechTime >= self.Config.DamageSpeechCooldown then
				self.LastDamageSpeechTime = now
				Speech.Say(self, Dialogue.GetDamageReactionLine(self))

				local threatRoot = WorldQuery.FindNearestPlayer(self, self.Config.ObservationRadius * 1.5)
				if threatRoot and self.StateMachine and self.StateMachine:GetStateName() ~= "Dead" then
					self.ObservationTarget = nil
					self.ObservationSecondaryTarget = nil
					self.ObservationLine = nil
					self.ObservationLookPosition = nil
					self.ObservationHoldDuration = self.Config.ObservationDuration
					self.ObservationShouldWave = false
					self.ObservationShouldAvoidAfter = false
					self.ObservationAvoidMode = "Sidestep"
					self.AvoidTarget = threatRoot
					self.AvoidLookTarget = threatRoot
					self.AvoidMode = "Flee"
					self.AvoidPauseUntil = 0
					self.AvoidUntil = now + self.Config.FleeDuration
					self.IgnoreObservationUntil = self.AvoidUntil
					self.StateMachine:SetState("AvoidFrontBlock")
				end
			end
		end

		self.LastHealth = newHealth
	end)
end

function NPCData:CharacterPool()
        if self.ECSEntity then
                NPCRegistry.Unregister(self.ECSEntity)
                ECS.deleteEntity(self.ECSEntity)
                self.ECSEntity = nil
        end
        self.StateThreadRunning = false

        if self.DiedConnection then
                self.DiedConnection:Disconnect()
		self.DiedConnection = nil
	end

	if self.HealthConnection then
		self.HealthConnection:Disconnect()
		self.HealthConnection = nil
	end

	if self.NPC.Parent then
		self.NPC:Destroy()
	end

	local template = ClonesFolder:FindFirstChild(self.Name)
	if not template or not template:IsA("Model") then
		warn(`[NPCData] No clone model found for {self.Name}`)
		return
	end

	local clone = template:Clone()
	clone.Parent = NPCFolder

	self.NPC = clone
	self.Humanoid = clone:WaitForChild("Humanoid") :: Humanoid
	self.Humanoid.WalkSpeed = self.Config.DefaultWalkSpeed
	self.PrimaryPart = WorldQuery.GetRootPart(clone)
	self.PrimaryPart:SetNetworkOwner(nil)
	self.NPC:PivotTo(self.StartPivot)

	self.Goal = clone:FindFirstChild("Goal") :: StringValue?
	self.Path = createPath()
	self.GoalDirection = "ToGoal"
	self.ObservationTarget = nil
	self.AvoidTarget = nil
	self.LastObservationTime = 0
	self.LastHealth = self.Humanoid.Health
	self.LastDamageSpeechTime = 0
	self.IdleUntil = 0
	self.AvoidUntil = 0
	self.AvoidPauseUntil = 0
	self.AbrasiveUntil = 0
	self.IgnoreObservationUntil = 0
	self.Disposition = getStartingDisposition()
	self.LastInteractionUserId = 0
	self.LastInteractionTime = 0
	self.RepeatInteractionCount = 0
	self.LastSpokenLine = ""
	self.ObservationSecondaryTarget = nil
	self.ObservationLine = nil
	self.ObservationLookPosition = nil
	self.ObservationHoldDuration = self.Config.ObservationDuration
	self.ObservationShouldWave = false
	self.ObservationShouldAvoidAfter = false
	self.ObservationAvoidMode = "Sidestep"
	self.AvoidLookTarget = nil
	self.AvoidMode = "Sidestep"

	local stateMachine = self.StateMachine
	if stateMachine then
		stateMachine:SetState("Patrol")
	end
	self:_ConnectDied()
	self:_ConnectHealthChanged()
	self:_StartStateLoop()
end

return NPCData
