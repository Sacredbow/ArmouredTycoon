--!strict
--[[
	@class ECSRuntime

	@desc
	Initializes the server-side ECS runner and registers all systems
	from organised subfolders (Combat, Tycoon, World, AI).
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Runner = require(ReplicatedStorage.ECS.Runner)
const ServerECS = script.Parent

--// Combat Systems

const DamageSystem = require(ServerECS.Systems.Combat.DamageSystem)
const StanceAnimationSystem = require(ServerECS.Systems.Combat.StanceAnimationSystem)
const WeaponRigSystem = require(ServerECS.Systems.Combat.WeaponRigSystem)

--// Tycoon Systems

const LifetimeSystem = require(ServerECS.Systems.Tycoon.LifetimeSystem)
const ProductionTickSystem = require(ServerECS.Systems.Tycoon.ProductionTickSystem)
const RevealSystem = require(ServerECS.Systems.Tycoon.RevealSystem)
const RocketFlightSystem = require(ServerECS.Systems.Tycoon.RocketFlightSystem)
const ScheduledTaskSystem = require(ServerECS.Systems.Tycoon.ScheduledTaskSystem)

--// World Systems

const EnvironmentClockSystem = require(ServerECS.Systems.World.EnvironmentClockSystem)
const TimedEmitterSystem = require(ServerECS.Systems.World.TimedEmitterSystem)
const TransformSyncSystem = require(ServerECS.Systems.World.TransformSyncSystem)

--// AI Systems

const NPCUpdateSystem = require(ServerECS.Systems.AI.NPCUpdateSystem)

--// Runner Initialization

local RunnerInstance = Runner.new("Server", ECS.world, ECS.Components)
RunnerInstance:AddSystem("DamageSystem", DamageSystem)
RunnerInstance:AddSystem("EnvironmentClockSystem", EnvironmentClockSystem)
RunnerInstance:AddSystem("LifetimeSystem", LifetimeSystem)
RunnerInstance:AddSystem("NPCUpdateSystem", NPCUpdateSystem)
RunnerInstance:AddSystem("RevealSystem", RevealSystem)
RunnerInstance:AddSystem("ProductionTickSystem", ProductionTickSystem)
RunnerInstance:AddSystem("RocketFlightSystem", RocketFlightSystem)
RunnerInstance:AddSystem("ScheduledTaskSystem", ScheduledTaskSystem)
RunnerInstance:AddSystem("StanceAnimationSystem", StanceAnimationSystem)
RunnerInstance:AddSystem("TimedEmitterSystem", TimedEmitterSystem)
RunnerInstance:AddSystem("TransformSyncSystem", TransformSyncSystem)
RunnerInstance:AddSystem("WeaponRigSystem", WeaponRigSystem)
RunnerInstance:Start(RunService.Heartbeat)
