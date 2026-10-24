--!strict
--[[
	@class ECS

	@desc
	Minimal jecs wrapper. Owns the shared ECS world and defines every
	component ahead of time. Components are flat data values queried by systems.
]]
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const jecs = require(ReplicatedStorage.Packages.jecs)

const ComponentNames = {
	"Name", "Model",
	"TycoonState", "TycoonPlot", "ModelRef", "Hierarchy", "Owner", "Collector",
	"Upgrades", "PurchasedButtons", "NeedsElectricity",
	"PlayerRef", "PlayerState", "PlayerMultiplier", "ArmourEquipped", "CanRebirth",
	"TeleportGrace", "Surrendering", "GamepassOwnership", "X2", "Electrified",
	"RocketActivated", "FriendBoost", "FriendBoostInitial", "FriendBoostRefresh",
	"PromptIntent", "ContactIntent", "TeleportPending", "SpawnProtection", "SpawnHighlight",
	"ElectricityImpact", "ElectricityCooldown", "LabDoor", "NukeCooldown", "RarityBoxLifetime", "RarityBoxSpawner", "RarityBoxState", "NukeSession", "NukeImpact", "NukeEnd",
	"LeaderboardBoard", "LeaderboardBoardTick", "LeaderboardWriteFlush", "KOTHZone", "KOTHContestant", "KOTHEnter",
	"EnvironmentWeatherTick", "EnvironmentShootingStarTick", "NPCRespawn", "RagdollRestore",
	"Transform", "Velocity", "Health", "Lifetime", "Producer", "Raycast",
	"PreviousPosition", "BuildItem", "Button", "Purchased", "Character",
	"CharacterMovement", "TimedEmitter", "DamageRequest", "WeaponRig",
	"StanceState", "NPCUpdate", "AntiCheatState",
	"EnvironmentClock", "DamageZone", "CreatorTagLifetime",
}

const World = jecs.World.new()
const Components: { [string]: any } = {}
for _, Name in ComponentNames do
	Components[Name] = World:component()
end

const ECS = {
	jecs = jecs,
	world = World,
	Components = table.freeze(Components),
}

function ECS.createEntity(ComponentData: { [string]: any }?): number
	const Entity = World:entity()
	if ComponentData then
		for ComponentName, Value in ComponentData do
			const Component = Components[ComponentName]
			if Component then
				World:set(Entity, Component, Value)
			else
				warn(`[ECS] Unknown component "{ComponentName}"`)
			end
		end
	end
	return Entity
end

function ECS.deleteEntity(Entity: number)
	World:delete(Entity)
end

function ECS.set(Entity: number, ComponentName: string, Value: any)
	const Component = Components[ComponentName]
	if not Component then error(`[ECS] Unknown component "{ComponentName}"`) end
	World:set(Entity, Component, Value)
end

function ECS.add(Entity: number, ComponentName: string)
	const Component = Components[ComponentName]
	if not Component then error(`[ECS] Unknown component "{ComponentName}"`) end
	World:add(Entity, Component)
end

function ECS.remove(Entity: number, ComponentName: string)
	const Component = Components[ComponentName]
	if not Component then error(`[ECS] Unknown component "{ComponentName}"`) end
	World:remove(Entity, Component)
end

function ECS.get(Entity: number, ComponentName: string): any
	const Component = Components[ComponentName]
	if not Component then error(`[ECS] Unknown component "{ComponentName}"`) end
	return World:get(Entity, Component)
end

return table.freeze(ECS)
