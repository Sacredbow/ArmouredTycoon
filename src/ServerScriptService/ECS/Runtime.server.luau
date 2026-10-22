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
const Observers = require(ReplicatedStorage.Packages.Observers)

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
const ScheduledTaskSystem = require(ServerECS.Systems.Tycoon.ScheduledTaskSystem)

--// World Systems

const EnvironmentClockSystem = require(ServerECS.Systems.World.EnvironmentClockSystem)
const TimedEmitterSystem = require(ServerECS.Systems.World.TimedEmitterSystem)
const TransformSyncSystem = require(ServerECS.Systems.World.TransformSyncSystem)

--// AI Systems

const NPCUpdateSystem = require(ServerECS.Systems.AI.NPCUpdateSystem)
const AntiCheatSystem = require(ServerECS.Systems.AI.AntiCheatSystem)

-- Tagged world geometry is promoted to plain ECS data. Systems can query
-- DamageZone without owning CollectionService connections or controller objects.
local _StopDamageZoneObserver = Observers.observeTag("DamageZone", function(instance: Instance)
	if not instance:IsA("BasePart") then
		return nil
	end

	local entity = ECS.createEntity({
		Name = instance:GetFullName() .. ":DamageZone",
		Model = instance,
		DamageZone = {
			Part = instance,
		},
	})

	return function()
		if ECS.world:get(entity, ECS.Components.DamageZone) then
			ECS.deleteEntity(entity)
		end
	end
end, { workspace })
--// Runner Initialization

local RunnerInstance = Runner.new("Server", ECS.world, ECS.Components)
RunnerInstance:AddSystem("DamageSystem", DamageSystem)
RunnerInstance:AddSystem("EnvironmentClockSystem", EnvironmentClockSystem)
RunnerInstance:AddSystem("LifetimeSystem", LifetimeSystem)
RunnerInstance:AddSystem("NPCUpdateSystem", NPCUpdateSystem)
RunnerInstance:AddSystem("AntiCheatSystem", AntiCheatSystem)
RunnerInstance:AddSystem("ProductionTickSystem", ProductionTickSystem)
RunnerInstance:AddSystem("ScheduledTaskSystem", ScheduledTaskSystem)
RunnerInstance:AddSystem("StanceAnimationSystem", StanceAnimationSystem)
RunnerInstance:AddSystem("TimedEmitterSystem", TimedEmitterSystem)
RunnerInstance:AddSystem("TransformSyncSystem", TransformSyncSystem)
RunnerInstance:AddSystem("WeaponRigSystem", WeaponRigSystem)
RunnerInstance:Start(RunService.Heartbeat)
