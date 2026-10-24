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

const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const Runner = require(ReplicatedStorage.Shared.Core.ECS.Runner)
const ServerECS = script.Parent
const ServerScriptService = game:GetService("ServerScriptService")
const TycoonSystems = ServerScriptService.Game.Tycoon.Systems
--// Combat Systems

const DamageSystem = require(ServerECS.Systems.Combat.DamageSystem)
const CreatorTagSystem = require(ServerECS.Systems.Combat.CreatorTagSystem)
const StanceAnimationSystem = require(ServerECS.Systems.Combat.StanceAnimationSystem)
const WeaponRigSystem = require(ServerECS.Systems.Combat.WeaponRigSystem)
--// Tycoon Systems

const LifetimeSystem = require(TycoonSystems.World.LifetimeSystem)
const ProductionTickSystem = require(TycoonSystems.Economy.ProductionTickSystem)
const PlayerLifecycleSystem = require(ServerECS.Systems.Lifecycle.PlayerLifecycleSystem)
const ClaimSystem = require(TycoonSystems.Interaction.ClaimSystem)
const ButtonSystem = require(TycoonSystems.Interaction.ButtonSystem)
const NukeSystem = require(TycoonSystems.Interaction.NukeSystem)
const GunSystem = require(TycoonSystems.Combat.GunSystem)
const TeleportSystem = require(TycoonSystems.Interaction.TeleportSystem)
const ElectricityTimerSystem = require(TycoonSystems.Economy.ElectricityTimerSystem)
const PowerSystem = require(TycoonSystems.Economy.PowerSystem)
const FriendBoostSystem = require(TycoonSystems.Economy.FriendBoostSystem)
const LabDoorSystem = require(TycoonSystems.Interaction.LabDoorSystem)
const NukeCooldownSystem = require(TycoonSystems.World.NukeCooldownSystem)
const RarityBoxSystem = require(TycoonSystems.World.RarityBoxSystem)
const ReloadSystem = require(TycoonSystems.Combat.ReloadSystem)
const ArmourSystem = require(TycoonSystems.Combat.ArmourSystem)
const LaserSystem = require(TycoonSystems.Combat.LaserSystem)
const CashCollectionSystem = require(TycoonSystems.Economy.CashCollectionSystem)
--// World Systems

const EnvironmentClockSystem = require(ServerECS.Systems.World.EnvironmentClockSystem)
const TimedEmitterSystem = require(ServerECS.Systems.World.TimedEmitterSystem)
const TransformSyncSystem = require(ServerECS.Systems.World.TransformSyncSystem)
--// AI Systems

const NPCUpdateSystem = require(ServerECS.Systems.AI.NPCUpdateSystem)
const AntiCheatSystem = require(ServerECS.Systems.AI.AntiCheatSystem)
const WorldTimerSystem = require(ServerECS.Systems.World.WorldTimerSystem)
const ActorTimerSystem = require(ServerECS.Systems.World.ActorTimerSystem)
const KOTHSystem = require(ServerECS.Systems.World.KOTHSystem)
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
RunnerInstance:AddSystem("PlayerLifecycleSystem", PlayerLifecycleSystem)
RunnerInstance:AddSystem("ClaimSystem", ClaimSystem)
RunnerInstance:AddSystem("ButtonSystem", ButtonSystem)
RunnerInstance:AddSystem("NukeSystem", NukeSystem)
RunnerInstance:AddSystem("GunSystem", GunSystem)
RunnerInstance:AddSystem("TeleportSystem", TeleportSystem)
RunnerInstance:AddSystem("ElectricityTimerSystem", ElectricityTimerSystem)
RunnerInstance:AddSystem("PowerSystem", PowerSystem)
RunnerInstance:AddSystem("FriendBoostSystem", FriendBoostSystem)
RunnerInstance:AddSystem("LabDoorSystem", LabDoorSystem)
RunnerInstance:AddSystem("NukeCooldownSystem", NukeCooldownSystem)
RunnerInstance:AddSystem("RarityBoxSystem", RarityBoxSystem)
RunnerInstance:AddSystem("ReloadSystem", ReloadSystem)
RunnerInstance:AddSystem("ArmourSystem", ArmourSystem)
RunnerInstance:AddSystem("LaserSystem", LaserSystem)
RunnerInstance:AddSystem("CashCollectionSystem", CashCollectionSystem)
RunnerInstance:AddSystem("DamageSystem", DamageSystem)
RunnerInstance:AddSystem("CreatorTagSystem", CreatorTagSystem)
RunnerInstance:AddSystem("EnvironmentClockSystem", EnvironmentClockSystem)
RunnerInstance:AddSystem("LifetimeSystem", LifetimeSystem)
RunnerInstance:AddSystem("NPCUpdateSystem", NPCUpdateSystem)
RunnerInstance:AddSystem("AntiCheatSystem", AntiCheatSystem)
RunnerInstance:AddSystem("ProductionTickSystem", ProductionTickSystem)
RunnerInstance:AddSystem("KOTHSystem", KOTHSystem)
RunnerInstance:AddSystem("WorldTimerSystem", WorldTimerSystem)
RunnerInstance:AddSystem("ActorTimerSystem", ActorTimerSystem)
RunnerInstance:AddSystem("StanceAnimationSystem", StanceAnimationSystem)
RunnerInstance:AddSystem("TimedEmitterSystem", TimedEmitterSystem)
RunnerInstance:AddSystem("TransformSyncSystem", TransformSyncSystem)
RunnerInstance:AddSystem("WeaponRigSystem", WeaponRigSystem)
RunnerInstance:Start(RunService.Heartbeat)
