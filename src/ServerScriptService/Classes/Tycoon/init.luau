--!strict
--[[
	@class Tycoon

	@desc
	Thin server-side orchestrator for each physical tycoon model in Workspace.Tycoons.
	Coordinates ownership, buttons, production, electricity, persistence, weapons,
	armour, reload prompts, nukes, rebirth, teleportation, and onboarding.

	Architecture:
	- Concrete behaviour lives in Systems/ modules that mix methods onto this class.
	- Utilities/ holds shared helpers (Cleanup, ValidatePromptRange).
	- ECS stores shared runtime entities (owners, buttons, scheduled tasks, rockets).
	- ProfileManager owns persistent data; PlayerRuntimeState owns fast flags.
]]

--// Services

const PhysicsService = game:GetService("PhysicsService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Packets = require(ReplicatedStorage.Network.Packets)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const ButtonConfiguration = require(script.Configuration.ButtonConfiguration)

const Assets = ReplicatedStorage:WaitForChild("Assets")

-- System mixins (self-require their own services/utilities).
const BuildSystem = require(script.Systems.BuildSystem)
const CollectorSystem = require(script.Systems.Production.CollectorSystem)
const ProductionSystem = require(script.Systems.Production.ProductionSystem)
const ElectricitySystem = require(script.Systems.Hazards.ElectricitySystem)
const PersistenceSystem = require(script.Systems.Persistence.PersistenceSystem)
const MigrationSystem = require(script.Systems.Persistence.MigrationSystem)
const AppearanceSystem = require(script.Systems.Appearance.AppearanceSystem)
const ClaimSystem = require(script.Systems.Ownership.ClaimSystem)
const ButtonSystem = require(script.Systems.Ownership.ButtonSystem)
const LabDoorSystem = require(script.Systems.Interaction.LabDoorSystem)
const ArmourSystem = require(script.Systems.Equipment.ArmourSystem)
const GunSystem = require(script.Systems.Equipment.GunSystem)
const LaserSystem = require(script.Systems.Hazards.LaserSystem)
const TeleportSystem = require(script.Systems.Interaction.TeleportSystem)
const NukeSystem = require(script.Systems.Interaction.NukeSystem)
const InteractionSystem = require(script.Systems.Interaction.InteractionSystem)

--// Module

const Tycoon = {}
Tycoon.__index = Tycoon
Tycoon.Registry = {}

--// Types

export type TycoonInstance = typeof(setmetatable({}, Tycoon)) & {
	Model: Model,
	Entity: any,
	PlayerService: any,
	PurchaseService: any,
	RagdollModule: any,
	CollisionManager: any,
	MainItems: Folder,
	Stages: Folder,
	Buttons: Folder,
	PurchasedItems: Folder,
	Droppers: Folder,
	GunModels: Folder,
	Components: Folder?,
	Audios: Folder?,
	DropperVisualsFolder: Folder,
	Owner: Player?,
	CharacterAddedConn: RBXScriptConnection?,
	ATM: Instance,
	CollectorAmount: number,
	CollectorDisplayLabel: TextLabel?,
	CollectorDisplayUpdatePending: boolean?,
	x2Upgraders: { [any]: boolean },
	x3Upgraders: { [any]: boolean },
	MovedItems: { [any]: any },
	ActiveDropperLoops: { [any]: any },
	AppliedUpgraders: { [any]: any },
	ItemEntities: { [any]: any },
	ButtonEntities: { [any]: any },
	PurchasedButtonLookup: { [string]: boolean },
	PurchasedButtonOrder: { string },
	TemplateCache: { [string]: Instance? },
	ArmourVest1: Instance,
	ArmourVest2: Instance,
	NPC_IdleAnimation: Instance,
	Activation: Instance,
	VisualEffects: Instance,
	Rocket: Model,
	IsSetup: boolean,
	ButtonTemplate: Folder,
	CompletedTycoon: boolean,
	ReloadConfigurationConnected: boolean?,
	TeleportConnections: { RBXScriptConnection }?,

	-- Ownership / lifecycle
	_SetupDoor: (self: TycoonInstance) -> (),
	_ClaimTycoon: (self: TycoonInstance, player: Player) -> (),
	_AssignTeam: (self: TycoonInstance, player: Player) -> (),
	_StartOnboarding: (self: TycoonInstance) -> (),
	Cleanup: (self: TycoonInstance) -> (),

	-- Appearance
	ApplyColors: (self: TycoonInstance) -> (),

	-- Buttons
	CheckCompletion: (self: TycoonInstance, buttonFolder: Folder) -> boolean,
	_SetupButtons: (self: TycoonInstance) -> (),
	_SetupButton: (self: TycoonInstance, button: BasePart) -> (),
	_GetButtonConfig: (self: TycoonInstance, buttonName: string) -> any,
	_MarkButtonPurchased: (self: TycoonInstance, button: BasePart, player: Player?) -> (),
	_ProcessButtonPurchase: (self: TycoonInstance, player: Player, button: BasePart) -> (),
	_UpdateRebirthAvailability: (self: TycoonInstance) -> (),

	-- Production / collector (existing mixins)
	_SetupUpgraders: (self: TycoonInstance) -> (),
	_StopAllDropperLoops: (self: TycoonInstance) -> (),
	_SetupAmmoArea: (self: TycoonInstance, dropper: Instance) -> (),
	_SetupCollector: (self: TycoonInstance) -> (),
	_QueueCollectorDisplayUpdate: (self: TycoonInstance, force: boolean?) -> (),
	_AddCollectorAmount: (self: TycoonInstance, amount: number) -> (),

	-- Build / persistence mixins
	_BuildTemplateCache: (self: TycoonInstance) -> (),
	_CheckDependencies: (self: TycoonInstance, config: any) -> boolean,
	_ApplyPurchasedButton: (self: TycoonInstance, button: BasePart, options: any?) -> boolean,
	_RestoreMovedItems: (self: TycoonInstance) -> (),
	_ResetConstructionTracking: (self: TycoonInstance) -> (),
	_SaveConstruction: (self: TycoonInstance, player: Player) -> (),
	_RestoreSavedConstruction: (self: TycoonInstance, player: Player) -> (),
	_MigrateConstruction: (self: TycoonInstance, player: Player) -> (),

	-- Hazards / interactions
	_SetupElectricity: (self: TycoonInstance) -> (),
	_SetupLabDoors: (self: TycoonInstance) -> (),
	_SetupArmour: (self: TycoonInstance) -> (),
	_SetupGuns: (self: TycoonInstance) -> (),
	_SetupLasers: (self: TycoonInstance) -> (),
	_SetupTeleportation: (self: TycoonInstance) -> (),
	_SetupProximityPrompts: (self: TycoonInstance) -> (),
	_SetupCollision: (self: TycoonInstance) -> (),
	_ReloadConfiguration: (self: TycoonInstance) -> (),
}

--// Collision group registration (module-level, runs once)

local function CollisionGroupExists(Name: string): boolean
	for _, Group in PhysicsService:GetRegisteredCollisionGroups() do
		if Group.name == Name then
			return true
		end
	end
	return false
end

if not CollisionGroupExists("Players") then
	PhysicsService:RegisterCollisionGroup("Players")
end

--// Dependency Injection — Systems mix methods onto the Tycoon class

BuildSystem(Tycoon, {})

CollectorSystem(Tycoon, {
	ProfileManager = ProfileManager,
	Packets = Packets,
})

ProductionSystem(Tycoon, {})

ElectricitySystem(Tycoon, {})

PersistenceSystem(Tycoon, {
	ProfileManager = ProfileManager,
})

MigrationSystem(Tycoon, {
	ProfileManager = ProfileManager,
})

AppearanceSystem(Tycoon, {})
ClaimSystem(Tycoon, {})
ButtonSystem(Tycoon, {})
LabDoorSystem(Tycoon, {})
ArmourSystem(Tycoon, {})
GunSystem(Tycoon, {})
LaserSystem(Tycoon, {})
TeleportSystem(Tycoon, {})
NukeSystem(Tycoon, {})
InteractionSystem(Tycoon, {})

--// Constructor

function Tycoon.new(TycoonModel: Model, PlayerService: any, PurchaseService: any, RagdollModule: any, CollisionManager: any): TycoonInstance
	const self = setmetatable({}, Tycoon) :: TycoonInstance

	self.Model = TycoonModel
	Tycoon.Registry[TycoonModel] = self

	self.Entity = ECS.createEntity({
		Name = TycoonModel.Name,
		Model = TycoonModel,
		Tycoon = self,
	})

	self.PlayerService = PlayerService
	self.PurchaseService = PurchaseService
	self.RagdollModule = RagdollModule
	self.CollisionManager = CollisionManager

	CollisionManager.Initialize()

	self.MainItems = TycoonModel:WaitForChild("MainItems") :: Folder
	self.Stages = TycoonModel:WaitForChild("Stages") :: Folder
	self.Buttons = TycoonModel:WaitForChild("Buttons") :: Folder
	self.PurchasedItems = TycoonModel:WaitForChild("PurchasedItems") :: Folder
	self.Droppers = TycoonModel:WaitForChild("Droppers") :: Folder
	self.GunModels = TycoonModel:WaitForChild("GunModels") :: Folder

	self.Components = TycoonModel:FindFirstChild("Components") :: Folder?
	self.Audios = TycoonModel:FindFirstChild("Audios") :: Folder?

	const DropperVisuals = TycoonModel:FindFirstChild("DropperVisuals")
	if DropperVisuals and DropperVisuals:IsA("Folder") then
		self.DropperVisualsFolder = DropperVisuals
	else
		self.DropperVisualsFolder = Instance.new("Folder")
		self.DropperVisualsFolder.Name = "DropperVisuals"
		self.DropperVisualsFolder.Parent = TycoonModel
	end

	self.Owner = nil :: Player?
	self.CharacterAddedConn = nil :: RBXScriptConnection?
	self.ATM = self.MainItems:WaitForChild("ATM")
	self.CollectorAmount = 0

	self.x2Upgraders = {}
	self.x3Upgraders = {}
	self.MovedItems = {}
	self.ActiveDropperLoops = {}
	self.AppliedUpgraders = {}
	self.ItemEntities = {}
	self.ButtonEntities = {}
	self.PurchasedButtonLookup = {}
	self.PurchasedButtonOrder = {}

	self.ArmourVest1 = Assets.CharacterItems.Armour.Armour1
	self.ArmourVest2 = Assets.CharacterItems.Armour.Armour2
	self.NPC_IdleAnimation = Assets:WaitForChild("Animations").NPC_Idle
	self.Activation = Assets["Visual Effects"].Activation
	self.VisualEffects = Assets["Visual Effects"]
	self.Rocket = (self.Components :: Folder):FindFirstChild("Rocket") :: Model

	self.IsSetup = false

	self.ButtonTemplate = self.Buttons:Clone() :: Folder
	self.ButtonTemplate.Parent = nil
	for _, Button in self.ButtonTemplate:GetChildren() do
		if Button:IsA("BasePart") then
			ButtonConfiguration.RemoveInstanceMetadata(Button)
		end
	end

	self.CompletedTycoon = false :: boolean

	return self
end

--// Public API — Init

function Tycoon.Init(self: TycoonInstance)
	if self.IsSetup then
		return
	end
	self.IsSetup = true

	warn("Initializing...:", self.Model.Name)

	self:_BuildTemplateCache()
	self:ApplyColors()
	self:_SetupDoor()
	self:_SetupButtons()
	self:_SetupCollector()
	self:_SetupUpgraders()
	self:_SetupElectricity()
	self:_SetupLasers()
	self:_SetupArmour()
	self:_SetupGuns()
	self:_SetupCollision()
	self:_SetupLabDoors()
	self:_ReloadConfiguration()
	self:_SetupTeleportation()
	self:_SetupProximityPrompts()
end

return Tycoon

