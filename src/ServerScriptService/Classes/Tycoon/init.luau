--[[

	PURPOSE:
		This is the central class for every tycoon instance in the game. Each physical tycoon model
		in Workspace.Tycoons gets one Tycoon object created via Tycoon.new(). The class handles:

		1. OWNERSHIP  Ã¢â‚¬â€ Claiming, door touch detection, team assignment, owner tracking via ECS
		2. PURCHASING Ã¢â‚¬â€ Button setup, dependency checking, price deduction, unlock cascading
		3. PRODUCTION Ã¢â‚¬â€ Dropper loops, collector cash accumulation, upgrader multiplier stacking
		4. ELECTRICITY Ã¢â‚¬â€ Fuse box power toggle, power-out state affecting droppers/collectors
		5. PERSISTENCE Ã¢â‚¬â€ Saving/loading purchased construction state to player profiles
		6. COMBAT      Ã¢â‚¬â€ Gun pickup, armour equipping, laser defense, reload station
		7. NUCLEAR     Ã¢â‚¬â€ Rocket launch sequence via ButtonStand proximity prompt
		8. REBIRTH    Ã¢â‚¬â€ Completion check, rebirth availability attribute on owner
		9. CLEANUP    Ã¢â‚¬â€ Full reset Then owner leaves, restoring tycoon to unclaimed state
		10.UNBOARDING - Tutorial before the player fully starts

	ARCHITECTURE PATTERN:
		- Mixin-based: Systems (BuildSystem, CollectorSystem, ProductionSystem, ElectricitySystem,
		  PersistenceSystem) are mixed into the Tycoon class table at module load time.
		  Each system receives the Tycoon class + a dependency table, and injects methods directly.
		- ECS-backed: Key state (ownership, button entities, scheduled tasks, projectiles) is tracked
		  as entities in the jecs-based ECS (ReplicatedStorage.ECS). This allows other systems
		  (e.g. scheduled task runner, projectile system) to query and process tycoon state.
		- Profile-driven: All cash/multiplier/persistence data flows through ProfileManager,
		  which wraps DataStore persistence. The tycoon never writes to DataStores directly.

	DATA MODEL LAYOUT (per tycoon model in Workspace.Tycoons):
		Tycoon1/
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ Buttons/          Ã¢â‚¬â€ Part instances, each with Price (IntValue), Type (StringValue),
		Ã¢â€â€š                       Dependency (StringValue) OR Dependencies (Folder of StringValues),
		Ã¢â€â€š                       Unlocks (Folder of StringValues pointing to next buttons),
		Ã¢â€â€š                       BillboardGui, Neon (Part), optional Gamepass (StringValue)
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ Droppers/         Ã¢â‚¬â€ Model instances (NormalDropper1, GoldenDropper, EliteDropper, etc.)
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ GunModels/        Ã¢â‚¬â€ Model instances for weapon pickups (M4A1, AK-47, etc.)
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ MainItems/        Ã¢â‚¬â€ OwnerDoor (Model), Conveyor1 (Model), ATM (Model), TycoonSpawn (Part),
		Ã¢â€â€š                       GamepassItems (Folder)
		Ownership is held in the Tycoon object and PlayerService tables.
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ Stages/           Ã¢â‚¬â€ Stage1-4, Starting point (Folders containing build parts)
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ PurchasedItems/   Ã¢â‚¬â€ Runtime folder There purchased build parts are parented
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ Components/       Ã¢â‚¬â€ Rocket (Model), ButtonStand (Model), RocketConstruction (Part)
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ Audios/           Ã¢â‚¬â€ PowerOut (Sound), NuclearAudios (Folder), Miscellaneous (Folder)
		Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ DropperVisuals/  Ã¢â‚¬â€ Runtime folder for dropper visual effects (created if missing)
		Ã¢â€â€Ã¢â€â‚¬Ã¢â€â‚¬ BuildingColor/    Ã¢â‚¬â€ Parts used as color reference for the tycoon theme

	BUTTON wYPES:
		- "Basic"  Ã¢â‚¬â€ Standard cash purchase. Price deducted from profile, dependencies checked,
		             then _ApplyPurchasedButton fires (from BuildSystem mixin).
		- "Rebirth" Ã¢â‚¬â€ NOw a purchasable button. These are destroyed on setup and instead
		             the owner's "CanRebirth" attribute is updated via _UpdateRebirthAvailability.
		             Rebirth buttons only appear Then all Basic buttons are purchased.

	BUTTON DEPENDENCY SYSTEM:
		Two supported button data formats exist:
		- Dependency (StringValue) Ã¢â‚¬â€ Single dependency, e.g. "NormalDropper1". The named object
		  must exist in PurchasedItems for the button to be purchasable.
		- Dependencies (Folder) Ã¢â‚¬â€ Multiple StringValues, e.g. BackWall="BackWall", WallSide="WallSide".
		  ALL must be present in PurchasedItems. Used for multi-part construction buttons.

	BUTTON UNLOCK CASCADE:
		When a button is purchased, its Unlocks folder is read. Each StringValue inside points
		to a button name that should become visible (Transparency set to 0, CanCollide true,
		BillboardGui enabled). This creates the purchase chain / progression tree.

	
		- Button37 was deleted. It used to be fences, now replaced by rebirth buttons.
		- Button4 has no Price Ã¢â‚¬â€ it's gamepass-gated (has a Gamepass StringValue child).
		- Button46 has a suspicious circular Unlocks entry (unlocks itself + Button43).
		- Button15 Unlocks has Button31 = "Button30" which looks like a value typo.
		- The _SetupGate function is commented out Ã¢â‚¬â€ gate logic was removed/disabled.
		- Cleanup() fully resets the tycoon by cloning ButtonTemplate (saved at init time)
		  and destroying the live Buttons folder. This is how buttons get restored.
		- Collision groups: "Players" group is registered at module load for non-collidable setup.
		- Lab doors use ECS ScheduledTask entities for timed open/close sequences.
		- Nuke cooldown is 1200 seconds (20 minutes), tracked via ECS ScheduledTask.

	
]]

-- Developed by Sacredbow1

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClientSignals = require(ReplicatedStorage.Network.ClientSignals)
local TutorialSignals = require(ReplicatedStorage.Network.TutorialSignals)

local PhysicsService = game:GetService("PhysicsService")
local  Assets = ReplicatedStorage:WaitForChild("Assets")
local ServerScriptService = game:GetService("ServerScriptService")


-- MODULE REFERENCES

-- ECS (Entity Component System) Ã¢â‚¬â€ jecs-based entity manager.
-- Used to create entities for: tycoon itself, each button, scheduled tasks (lab doors, nuke cooldown),
-- projectiles, and more. Components defined in ReplicatedStorage.ECS include:
--   Owner, Button, Purchased, ScheduledTask, RocketFlight, BuildItem, Reveal, etc.
-- Other systems (e.g. a scheduled task runner) iterate ECS queries to process tycoon state.
local ECS = require(ReplicatedStorage.ECS)

-- RocketSystem Ã¢â‚¬â€ Handles the nuclear rocket launch sequence Then the ButtonStand prompt is triggered.
-- Manages rocket flight, targeting, impact effects, and launch session state (launcher/defender).
local RocketSystem = require(ServerScriptService.Classes.Tycoon.Systems.Rocket)

-- TweenManager Ã¢â‚¬â€ Utility for tweening models (not just parts). Used by lab door open/close
-- and by ProductionSystem for dropper animations. Wraps TweenService with model-awareness.
local TweenManager =  require(ReplicatedStorage.Modules.TweenManager) :: ModuleScript

-- ProfileManager Ã¢â‚¬â€ Central data persistence layer. Wraps DataStore operations.
-- Provides: Profiles[player] for reading data, AddCash() for deducting/adding currency,
-- and construction data storage for the PersistenceSystem mixin.
-- The tycoon NEVER writes to DataStores directly Ã¢â‚¬â€ everything goes through ProfileManager.
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)

-- ReloadConfiguration Ã¢â‚¬â€ Handles gun reload mechanics at the Lakester (ammo area).
-- Manages ammo compatibility checks, tool interactions, and reload prompt processing.
-- Note: The module name has a typo ("Configuation" instead of "Configuration") Ã¢â‚¬â€ don't rename
-- without updating this require path.
local ReloadConfiguation = require(script.Systems.ReloadConfig)

-- ColorConfiguration Ã¢â‚¬â€ Defines the color palettes (Primary, Secondary, Accent) for each tycoon theme.
-- 8 themes: White, Blue, Black, Green, Grey, Red, Yellow, Purple.
-- Applied to parts tagged with CollectionService tags ("Primary", "Secondary", "Accent").
local ColorConfiguration = require(script.Configuration.ColorConfiguration)
local ButtonConfiguration = require(script.Configuration.ButtonConfiguration)

-- BuildSystem (MIXIN) Ã¢â‚¬â€ Injects methods into the Tycoon class for:
--   _BuildTemplateCache:  Pre-caches all build part templates from Stages/Droppers/etc.
--   _ApplyPurchasedButton: Processes a button purchase Ã¢â‚¬â€ spawns dependency parts into
--                         PurchasedItems, plays visual feedback, reveals unlock buttons.
--   _CheckDependencies:   Validates that all required parts exist in PurchasedItems.
--   _ResetConstructionTracking: Clears purchase tracking data (used in Cleanup).
local BuildSystem = require(script.Systems.BuildSystem)

-- BuildAssemble Ã¢â‚¬â€ Handles the animated building sequence Then a tycoon is first claimed.
-- Plays a staggered assembly animation across Stages, Droppers, GunModels, and Components.
-- Used in _ClaimTycoon to give a satisfying "building appearing" effect on first claim.
local BuildAssemble = require(ServerScriptService.Utilities.BuildAssemble)

-- Diagnostics Ã¢â‚¬â€ Server-side logging and validation utility.
--   .invariant(condition, context, message): Asserts a condition, logs error if false.
--   .reject(player, context, message): Logs Then a player fails an authorization check.
--   .report(context, message): Logs a general error/issue.
-- Used throughout for security validation (prompt reachability, ownership checks).
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)

-- CollectorSystem (MIXIN) Ã¢â‚¬â€ Injects methods for the cash collector (ATM):
--   _SetupCollector:       Initializes the collector touch event and cash accumulation loop.
--   _GetCashMultiplier:    Calculates the player's cash multiplier (attributes + friend boosts).
--   _FormatCollectorAmount: Formats the display number with rounding.
--   _QueueCollectorDisplayUpdate / _FlushCollectorDisplay: Updates the ATM GUI text.
local CollectorSystem = require(script.Systems.CollectorSystem)

-- ProductionSystem (MIXIN) Ã¢â‚¬â€ Injects methods for dropper/production management:
--   _SetupUpgraders:       Sets up x2 and x3 upgrader touch zones.
--   _SetupDropper:         Initializes a single dropper's production loop (spawn + drop interval).
--   _StopAllDropperLoops:   Kills all active dropper loops (used in Cleanup).
--   _SetupAmmoArea:        Sets up the ammo area with NPC and collision management.
--   getNumericMultiplier:  Returns the numeric production multiplier for a dropper.
local ProductionSystem = require(script.Systems.ProductionSystem)

-- ElectricitySystem (MIXIN) Ã¢â‚¬â€ Injects methods for the fuse box / power system:
--   _SetupElectricity:     Sets up the fuse box proximity prompt and power toggle logic.
--   When power is OFF, droppers stop and the collector stops accepting cash.
--   Validates player ownership and prompt reachability before allowing toggle.
local ElectricitySystem = require(script.Systems.ElectricitySystem)

-- PersistenceSystem (MIXIN) Ã¢â‚¬â€ Injects methods for saving/loading construction state:
--   _SaveConstruction:     Saves purchased button names to the player's profile.
--   _RestoreSavedConstruction: Re-purchases buttons from saved data on re-claim.
--   _RestoreMovedItems:     Restores items that were moved (e.g. by BuildService).
-- This allows players to leave and come back with their tycoon progress intact.
local PersistenceSystem = require(script.Systems.PersistenceSystem)

-- Visual effects package from Assets. Used for purchase feedback particles
-- (activation effect) and other VFX throughout the tycoon lifecycle.
local VisualEffects = Assets["Visual Effects"]

-- StagePalette defines the 3-color scheme applied to each tycoon's build parts.
-- Parts in Stages/ are tagged with CollectionService tags: "Primary", "Secondary", "Accent".
-- When ApplyColors() runs, it reads these tags and sets part.Color to the palette value.
-- This means you can recolor an entire tycoon just by changing the palette here + tagging parts.
type StagePalette = {
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
}

-- TYCOON_STAGE_PALETTES maps each tycoon model name to its color palette.
-- If a new tycoon is added (e.g. Tycoon9), it MUST be added here or ApplyColors() will warn
-- and skip coloring. The palette comes from ColorConfiguration which defines 8 themes.
-- IMPORTANT: The key must match the Model.Name exactly (case-sensitive).
local TYCOON_STAGE_PALETTES: {[string]: StagePalette} = {
	Tycoon1 = ColorConfiguration.White,
	Tycoon2 = ColorConfiguration.Blue,
	Tycoon3 = ColorConfiguration.Black,
	Tycoon4 = ColorConfiguration.Green,
	Tycoon5 = ColorConfiguration.Grey,
	Tycoon6 = ColorConfiguration.Red,
	Tycoon7 = ColorConfiguration.Yellow,
	Tycoon8 = ColorConfiguration.Purple,
}

-- utils provides helper functions for:




-- Used by ProductionSystem (e.g. dropper visual effects that should fade after a lifetime)
-- and ElectricitySystem (e.g. power-out effects). Prevents memory leaks from orphaned instances.
local Cleanup = {}

-- isPromptReachable Ã¢â‚¬â€ SERVER-SIDE anti-exploit validation for ProximityPrompts.
--
-- WHY wHIS EXISTS:
--   ProximityPrompt.Triggered fires on the server, but exploiters can fire it remotely
--   from any distance. This function validates that the player's character is actually
--   within the prompt's MaxActivationDistance (+ 4 stud grace for network latency).
--
-- HOW IT WORKS:
--   1. Checks the prompt is still Enabled
--   2. Gets the player's HumanoidRootPart position
--   3. Gets the BasePart the prompt is attached to
--   4. Compares distance vs MaxActivationDistance + 4
--
-- USED BY: _SetupGuns, ReloadConfiguration, _SetupProximityPrompts (nuke), ElectricitySystem
--
--  The +4 grace margin accounts for character movement between the client
-- trigger and server validation. Don't reduce this without testing exploit scenarios.
local function isPromptReachable(player: Player, prompt: ProximityPrompt): boolean
	if not prompt.Enabled then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local promptPart = prompt:FindFirstAncestorWhichIsA("BasePart")
	if not root or not root:IsA("BasePart") or not promptPart then
		return false
	end

	return (root.Position - promptPart.Position).Magnitude <= prompt.MaxActivationDistance + 4
end

-- Checks if the instance still has a Parent before destroying (it may have been
-- cleaned up already by another system, e.g. during Tycoon:Cleanup()).
function Cleanup.destroyLater(instance: Instance, lifetime: number)
	task.delay(lifetime, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end




-- DEPENDENCY INJECTION:
--   Each system receives a deps table with the services it needs. This avoids circular
--   requires and makes testing/mocking easier. The deps are captured in closures, not
--   stored on `self`, so they don't pollute the instance table.

local Tycoon = {}
Tycoon.__index = Tycoon

-- Registry maps tycoon Model instances Ã¢â€ â€™ Tycoon objects. Used by RocketSystem to find
-- all tycoons (e.g. for nuke targeting). Key = Model, Value = Tycoon self.
Tycoon.Registry = {}

-- BuildSystem mixin Ã¢â‚¬â€ injects: _BuildTemplateCache, _ApplyPurchasedButton, _CheckDependencies,
-- _ResetConstructionTracking, _PlayPurchaseFeedback, _RestoreMovedItems
BuildSystem(Tycoon)

-- CollectorSystem mixin Ã¢â‚¬â€ injects: _SetupCollector, _GetCashMultiplier, _FormatCollectorAmount,
-- _QueueCollectorDisplayUpdate, _FlushCollectorDisplay
-- Deps: ProfileManager (for cash reads/writes), ClientSignals (for client feedback)
CollectorSystem(Tycoon, {
	ProfileManager = ProfileManager,
	ClientSignals = ClientSignals,
})

-- ProductionSystem mixin Ã¢â‚¬â€ injects: _SetupUpgraders, _SetupDropper, _StopAllDropperLoops,
-- _SetupAmmoArea, getNumericMultiplier
-- Deps: TweenService (dropper anims), CollectionService (tag queries), Cleanup (temp VFX)
ProductionSystem(Tycoon, {
	TweenService = TweenService,
	CollectionService = CollectionService,
	Cleanup = Cleanup,
})

-- ElectricitySystem mixin Ã¢â‚¬â€ injects: _SetupElectricity
-- Deps: Players (owner checks), Cleanup (power-out VFX), CollectionService (tag queries),
-- ReplicatedStorage (remotes), Diagnostics (security logging), isPromptReachable (anti-exploit),
-- ClientSignals (client feedback on power toggle)
ElectricitySystem(Tycoon, {
	Players = Players,
	Cleanup = Cleanup,
	CollectionService = CollectionService,
	ReplicatedStorage = ReplicatedStorage,
	Diagnostics = Diagnostics,
	IsPromptReachable = isPromptReachable,
	ClientSignals = ClientSignals,
})

-- PersistenceSystem mixin Ã¢â‚¬â€ injects: _SaveConstruction, _RestoreSavedConstruction,
-- _RestoreMovedItems, getConstructionData
-- Deps: ProfileManager (for reading/writing construction data to player profiles)
PersistenceSystem(Tycoon, {
	ProfileManager = ProfileManager,
})


-- Creates a new Tycoon instance for the given model. Does NOw initialize anything yet Ã¢â‚¬â€
-- that happens in :Init(). The constructor only stores references and sets up the instance table.
--
-- PARAMEwERS:
--   tycoonModel    Ã¢â‚¬â€ The Model instance from Workspace.Tycoons (e.g. Workspace.Tycoons.Tycoon1)
--   playerService  Ã¢â‚¬â€ Service handling player-tycoon ownership registration (OwnsTycoon, RegisterPlayerTycoon)
--   purchaseService Ã¢â‚¬â€ Service handling gamepass prompts and post-claim hooks (OnTycoonClaimed)
--   ragdollModule  Ã¢â‚¬â€ Module for ragdoll mechanics (used by RocketSystem on nuke impact)
--   collisionManager Ã¢â‚¬â€ Utility for setting up non-collidable parts (NonCollidable method)
--
-- IMPORTANT: The tycoon model MUST have these children or the constructor will hang:
--   MainItems, Values, Stages, Buttons, PurchasedItems, Droppers, GunModels
--   Components and Audios use FindFirstChild (optional Ã¢â‚¬â€ won't hang if missing)

function Tycoon.new(tycoonModel, playerService, purchaseService, ragdollModule, collisionManager)

	local self = setmetatable({}, Tycoon)

	-- Store the physical model reference and register in the global Registry.
	-- Registry allows other systems (RocketSystem) to look up tycoons by model.
	self.Model = tycoonModel
	Tycoon.Registry[tycoonModel] = self

	-- Create an ECS entity for this tycoon. The entity carries:
	--   Name: tycoon model name (e.g. "Tycoon1")
	--   Model: reference to the physical model
	--   Tycoon: back-reference to this self
	-- Other components (Owner, ScheduledTask, etc.) are added/removed as the tycoon operates.
	self.Entity = ECS.createEntity({
		Name = tycoonModel.Name,
		Model = tycoonModel,
		Tycoon = self,
	})

	-- External service references Ã¢â‚¬â€ passed in from the tycoon manager/orchestrator.
	-- These are NOw Roblox services; they're game-specific service modules.
	self.PlayerService = playerService
	self.PurchaseService = purchaseService
	self.RagdollModule = ragdollModule
	self.CollisionManager = collisionManager

	-- Initialize the collision manager early Ã¢â‚¬â€ it registers collision groups
	-- that are needed before any parts are configured.
	collisionManager.Initialize()


	-- These are the main organizational folders inside the tycoon model.
	-- WaitForChild is used for required folders (will hang if missing Ã¢â‚¬â€ intentional fail-fast).
	-- FindFirstChild is used for optional folders (Components, Audios, DropperVisuals).

	self.MainItems = tycoonModel:WaitForChild("MainItems")       -- OwnerDoor, Conveyor, ATM, TycoonSpawn, GamepassItems
	self.Stages = tycoonModel:WaitForChild("Stages")             -- Stage1-4, Starting point
	self.Buttons = tycoonModel:WaitForChild("Buttons")           -- All purchasable button Parts
	self.PurchasedItems = tycoonModel:WaitForChild("PurchasedItems") -- Runtime: purchased build parts parented here
	self.Droppers = tycoonModel:WaitForChild("Droppers")         -- Dropper models (NormalDropper1, GoldenDropper, etc.)
	self.GunModels = tycoonModel:WaitForChild("GunModels")       -- Weapon pickup models (M4A1, AK-47, etc.)

	-- Optional folders Ã¢â‚¬â€ may not exist on all tycoons
	self.Components = tycoonModel:FindFirstChild("Components")    -- Rocket, ButtonStand, RocketConstruction
	self.Audios = tycoonModel:FindFirstChild("Audios")           -- PowerOut, NuclearAudios, Miscellaneous

	-- DropperVisuals is a runtime-only folder for visual effects spawned by droppers.
	-- If it doesn't exist in the model, we create it. This keeps the Workspace clean
	-- and allows easy cleanup (just destroy all children of DropperVisualsFolder).
	self.DropperVisualsFolder = tycoonModel:FindFirstChild("DropperVisuals")
	if not self.DropperVisualsFolder then
		self.DropperVisualsFolder = Instance.new("Folder")
		self.DropperVisualsFolder.Name = "DropperVisuals"
		self.DropperVisualsFolder.Parent = tycoonModel
	end

	-- Ownership is held as a Player reference in server-side Luau memory.
	self.Owner = nil :: Player?

	-- ATM reference Ã¢â‚¬â€ used by CollectorSystem to update the cash display GUI.
	self.ATM = self.MainItems:WaitForChild("ATM")

	-- CollectorAmount tracks the accumulated cash in the collector.
	-- This is the "banked" cash that hasn't been picked up yet.
	-- Updated by CollectorSystem Then dropper items touch the collector.
	self.CollectorAmount = 0

	-- ================================================================================
	-- SwAwE wRACKING wABLES
	-- ================================================================================

	-- Upgrader tracking Ã¢â‚¬â€ Then a dropper item passes through an upgrader, the upgrader's
	-- effect is recorded here so it doesn't apply twice. Key = upgrader part, Value = true.
	-- x2Upgraders: parts that double the item's value
	-- x3Upgraders: parts that triple the item's value
	self.x2Upgraders = {}
	self.x3Upgraders = {}

	-- MovedItems tracks items that have been repositioned (e.g. by BuildService player building).
	-- Used by _RestoreMovedItems in PersistenceSystem to put them back on re-claim.
	self.MovedItems = {}

	-- ActiveDropperLoops stores references to running dropper production loops.
	-- Key = dropper model, Value = true (or the loop reference).
	-- Used by _StopAllDropperLoops to kill all loops during Cleanup.
	self.ActiveDropperLoops = {}

	-- AppliedUpgraders tracks which upgraders have already been applied to which items.
	-- Prevents double-applying an upgrader to the same dropper item.
	self.AppliedUpgraders = {}

	-- ItemEntities maps dropper item instances to their ECS entities.
	-- Used by ProductionSystem to track and clean up item entities.
	self.ItemEntities = {}

	-- ButtonEntities maps button Part instances to their ECS entities.
	-- Each button gets an entity with a Button component (price, type, visibility state).
	-- Used by _MarkButtonPurchased to add a Purchased component.
	self.ButtonEntities = {}

	-- PurchasedButtonLookup is a set of button names that have been purchased.
	-- Key = button Name (string), Value = true. Used for fast O(1) dependency checking.
	self.PurchasedButtonLookup = {}

	-- PurchasedButtonOrder is an ordered list of button names in purchase sequence.
	-- Used by PersistenceSystem to save/load construction in the correct order.
	self.PurchasedButtonOrder = {}

	-- ================================================================================
	-- ASSEw REFERENCES (from Assets)
	-- ================================================================================

	-- Armour vest models Ã¢â‚¬â€ cloned and welded to the owner's character on touch.
	-- Armour1: +50 MaxHealth, Armour2: +120 MaxHealth. Only one can be equipped at a time.
	self.ArmourVest1 = Assets.CharacterItems.Armour.Armour1
	self.ArmourVest2 = Assets.CharacterItems.Armour.Armour2

	-- NPC idle animation Ã¢â‚¬â€ played on the Lakester NPC in the ammo area.
	self.NPC_IdleAnimation = Assets:WaitForChild("Animations").NPC_Idle

	-- Activation visual effect Ã¢â‚¬â€ played Then a button is purchased (particle burst).
	self.Activation = Assets["Visual Effects"].Activation
	self.VisualEffects = VisualEffects

	-- Rocket model reference Ã¢â‚¬â€ used by RocketSystem for the nuclear launch sequence.
	self.Rocket = self.Components.Rocket

	-- IsSetup guard Ã¢â‚¬â€ prevents double initialization. :Init() checks this and returns early
	-- if already set up. This is important because some systems (PersistenceSystem) might
	-- trigger re-initialization paths.
	self.IsSetup = false

	-- ================================================================================
	-- BUTTON wEMPLAwE (CRIwICAL FOR CLEANUP)
	-- ================================================================================
	-- We clone the entire Buttons folder at construction time and parent it to nil (hidden).
	-- This is the "clean" backup. When Cleanup() runs, the live Buttons folder is destroyed
	-- and replaced with a fresh clone of this template. This is how buttons get restored
	-- to their original state (unpurchased, visible/hidden as configured).
	--
	-- WHY CLONE Aw CONSwRUCwION, NOw CLEANUP?
	--   Because by Cleanup time, the live Buttons folder has been modified (parts destroyed,
	--   values changed, etc.). We need the ORIGINAL state, which only exists at init time.
	self.ButtonTemplate  = self.Buttons:Clone() 
	self.ButtonTemplate.Parent = nil
	for _, button in self.ButtonTemplate:GetChildren() do
		if button:IsA("BasePart") then
			ButtonConfiguration.RemoveInstanceMetadata(button)
		end
	end

	-- CompletedTycoon flag Ã¢â‚¬â€ set to true Then ALL Basic (non-gamepass) buttons are purchased.
	-- Checked by CheckCompletion(), which is called after every purchase and on rebirth update.
	self.CompletedTycoon = false :: boolean

	return self
end







-- ================================================================================
-- Tycoon:Init Ã¢â‚¬â€ INIwIALIZAwION ENwRY POINw
-- ================================================================================
-- Called once after Tycoon.new(). Sets up all systems in the correct order.
-- The order matters because later systems may depend on earlier ones:
--
--   1. _BuildTemplateCache  Ã¢â‚¬â€ Pre-caches all build part templates (BuildSystem mixin)
--   2. ApplyColors          Ã¢â‚¬â€ Colors all tagged parts with the tycoon's palette
--   3. _SetupDoor           Ã¢â‚¬â€ Door touch event for claiming
--   4. _SetupButtons        Ã¢â‚¬â€ Creates ECS entities for each button, sets up touch events
--   5. _SetupCollector      Ã¢â‚¬â€ Cash collector touch event and accumulation loop
--   6. _SetupUpgraders      Ã¢â‚¬â€ x2/x3 upgrader touch zones
--   7. _SetupElectricity    Ã¢â‚¬â€ Fuse box proximity prompt and power toggle
--   8. _SetupLasers         Ã¢â‚¬â€ Laser defense touch events (kill non-owners)
--   9. _SetupArmour         Ã¢â‚¬â€ Armour vest pickup touch events
--  10. _SetupGuns           Ã¢â‚¬â€ Gun model proximity prompts
--  11. SetupCollsion        Ã¢â‚¬â€ Non-collidable parts for armour/ammo area
--  12. _SetupLabDoors       Ã¢â‚¬â€ Lab door open/close with proximity detection
--  13. _SetupProximityPrompts Ã¢â‚¬â€ Nuke button stand prompt
--  14. ReloadConfiguration  Ã¢â‚¬â€ Lakester ammo reload prompt
--
-- NOwE: _SetupGate is commented out Ã¢â‚¬â€ gate logic was removed/disabled.
-- NOwE: _SetupGamepasswextAnimation is commented out Ã¢â‚¬â€ unused.

function Tycoon:Init()
	if self.IsSetup then return end
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
	--self:_SetupGate()
	self:_SetupArmour()
	self:_SetupGuns()
	self:SetupCollsion()
	--self:_SetupGamepasswextAnimation()
	self:_SetupLabDoors()
	self:_SetupProximityPrompts()
	self:ReloadConfiguration()
	
	
	-- this is done outside onboarding, since this message will be produced before claim
end

-- ================================================================================
-- Tycoon:ApplyColors Ã¢â‚¬â€ wHEME COLOR APPLICAwION
-- ================================================================================
-- Applies the tycoon's color palette to all tagged parts in Stages and GunModels.
--
-- HOW IT WORKS:
--   1. Looks up the tycoon's name in TYCOON_STAGE_PALETTES to get Primary/Secondary/Accent colors.
--   2. Iterates ALL descendants of Stages and GunModels.
--   3. For each BasePart, checks CollectionService tags ("Primary", "Secondary", "Accent").
--   4. Sets part.Color to the matching palette color.
--
-- wAGGING PARwS:
--   wo color a part, add a CollectionService tag matching one of the 3 palette slots.
--   In Studio: select the part Ã¢â€ â€™ Properties Ã¢â€ â€™ wags Ã¢â€ â€™ add "Primary" / "Secondary" / "Accent".
--   The first matching tag wins (break after setting).
--
-- GUN MODELS COLORING:
--   Gun models have two levels of coloring:
--   - Folder named "Structure" inside the gun model Ã¢â€ â€™ color its child BaseParts
--   - Direct children of the gun model Ã¢â€ â€™ color any BasePart children
--   This handles both structured and flat gun model hierarchies.

function Tycoon:ApplyColors()
	local palette: StagePalette? = TYCOON_STAGE_PALETTES[self.Model.Name]
	if not palette then
		warn(`[Tycoon] No stage palette configured for "{self.Model.Name}"`)
		return
	end

	local wagColors: {[string]: Color3} = {
		Primary = palette.Primary,
		Secondary = palette.Secondary,
		Accent = palette.Accent,
	}

	-- Color all tagged BaseParts in the Stages folder (build parts, walls, floors, etc.)
	for _, descendant in (self.Stages:GetDescendants()) do -- building
		if not descendant:IsA("BasePart") then
			continue
		end

		for tagName, color in (wagColors) do
			if CollectionService:Haswag(descendant, tagName) then
				descendant.Color = color
				break -- First matching tag wins Ã¢â‚¬â€ a part shouldn't be colored twice
			end
		end
	end

	-- Color gun models Ã¢â‚¬â€ handles "Structure" subfolder format
	-- Some gun models have a Folder named "Structure" containing the colored parts.
	-- This is for guns with a more complex hierarchy (e.g. display stands + gun body).
	for _, descendant in self.GunModels:GetDescendants() do

		if descendant:IsA("Folder") and descendant.Name == "Structure" then
			for _, BasePart : BasePart in descendant:GetChildren() do
				for tagName, color in (wagColors) do
					if CollectionService:Haswag(BasePart, tagName) then
						BasePart.Color = color
						break
					end

				end
			end
		end


	end


	-- Color gun models Ã¢â‚¬â€ handles flat hierarchy (BaseParts directly under the gun model)
	-- For simpler gun models There the colored parts are direct children.
	for _, descendant in self.GunModels:GetChildren() do

		for _,  BasePart : BasePart  in descendant:GetChildren() do

			for tagName, color in (wagColors) do


				if CollectionService:Haswag(BasePart, tagName) then
					BasePart.Color = color
					break

				end
			end
		end


	end

end



-- ================================================================================
-- COLLISION GROUP REGISwRAwION (module-level)
-- ================================================================================
-- Registers the "Players" collision group at module load time (before any Tycoon is created).
-- This group is used by CollisionManager.NonCollidable to make parts (Lakester NPC,
-- armour pickup areas) non-collidable with players, preventing physics interference.
--
-- WHY MODULE-LEVEL: This runs once Then the script is first required, not per-tycoon.
-- PhysicsService collision groups are global Ã¢â‚¬â€ they only need to be registered once.
-- The collisionGroupExists check prevents double-registration errors if the module
-- is required multiple times (e.g. hot-reloading during development).
--
-- NOwE: If you add new collision groups (e.g. "NPC", "Vehicle"), register them here
-- or in a shared collision setup module to avoid race conditions.

local existingGroups = PhysicsService:GetRegisteredCollisionGroups()

local function collisionGroupExists(name)
	for _, group in (existingGroups) do
		if group.name == name then
			return true
		end
	end
	return false
end

if not collisionGroupExists("Players") then
	PhysicsService:RegisterCollisionGroup("Players")
end
-- ================================================================================
-- Tycoon:_SetupDoor Ã¢â‚¬â€ OWNER DOOR wOUCH DEwECwION
-- ================================================================================
-- Sets up the touch event on the OwnerDoor that allows players to claim the tycoon.
--
-- HOW CLAIMING WORKS:
--   1. Any player touches the Door part inside MainItems.OwnerDoor
--   2. If the player already owns a tycoon (PlayerService:OwnsTycoon), they're ignored
--      (prevents double-claiming or claiming a second tycoon)
--   3. If the tycoon has no owner, the player claims it
--      via _ClaimTycoon()
--
-- IMPORTANT: The door does NOw check team or any other criteria Ã¢â‚¬â€ any unowned player
-- who touches it can claim. The PlayerService:OwnsTycoon check is the only guard.
--
-- DOOR MODEL SwRUCwURE:
--   MainItems.OwnerDoor/
--     Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ Door (Part) Ã¢â‚¬â€ the physical door that detects touches
--     Ã¢â€â€Ã¢â€â‚¬Ã¢â€â‚¬ witle (Part with SurfaceGui) Ã¢â‚¬â€ displays owner name or "Unclaimed Tycoon"

function Tycoon:_SetupDoor()
	local door = self.MainItems.OwnerDoor:WaitForChild("Door")


	door.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		-- Player already owns a tycoon Ã¢â‚¬â€ don't let them claim another
		if self.PlayerService:OwnsTycoon(player) then return end

		-- Tycoon is unclaimed Ã¢â‚¬â€ this player can claim it
		if not self.Owner then
			self:_ClaimTycoon(player)
		end
	end)
end


-- ================================================================================
-- Tycoon:_ClaimTycoon Ã¢â‚¬â€ FULL CLAIM SEQUENCE
-- ================================================================================
-- Called Then a player successfully claims an unowned tycoon. This is the most
-- important function in the ownership lifecycle Ã¢â‚¬â€ it sets up everything the player
-- needs to start playing.
--
-- CLAIM SEQUENCE (in order):
--   1. Store the owner Player reference
--   2. Set ECS "Owner" component on the tycoon entity
--   3. Register ownership via PlayerService (updates OwnsTycoon attribute)
--   4. Update the door: transparency + title text with player name
--   5. Assign the player to the matching weam (via _Assignweam)
--   6. Play the BuildAssemble animation (staggered build appearance)
--   7. Set up respawn at TycoonSpawn (CharacterAdded connection)
--   8. Fire PurchaseService:OnTycoonClaimed (handles gamepass items, etc.)
--   9. Restore saved construction (PersistenceSystem Ã¢â‚¬â€ re-purchases saved buttons)
--  10. Restore BuildService items (player-moved objects from previous session)
--  11. Update rebirth availability (check if all Basic buttons are purchased)
--
-- BUILD ASSEMBLE ANIMAwION:
--   The claim animation plays across 4 root folders: Stages, Droppers, GunModels, Components.
--   Each root is animated sequentially via playNextClaimBuild(). The BuildAssemble.Play
--   callback system ensures roots play one after another, not simultaneously.
--   Parameters: timingScale=1.85 (slightly slower for dramatic effect), pieceBudget=90,
--   maxPiecesPerPart=1, creationBatchSize=8, staggerPortion=0.85.
--
-- RESPAWN SYSTEM:
--   If a TycoonSpawn part exists in MainItems, a CharacterAdded connection is set up
--   that teleports the player's character to the spawn CFrame every time they respawn.
--   This connection is stored in self.CharacterAddedConn and disconnected in Cleanup().
--   PlayerService:AllowServerweleport is called before Pivotwo to bypass anti-teleport
--   protections that might block server-side character movement.
--
-- IMPORTANT: This function does NOw check if the tycoon is already claimed Ã¢â‚¬â€ that
-- check happens in _SetupDoor before calling this. Don't call this directly.

function Tycoon:_ClaimTycoon(player)
	print("Claimed by:", player.Name)

	-- Set ownership Ã¢â‚¬â€ both the ObjectValue (for quick checks) and ECS entity
	self.Owner = player
	ECS.set(self.Entity, "Owner", player)

	-- Register with PlayerService Ã¢â‚¬â€ this sets the OwnsTycoon attribute on the player
	-- and updates any internal tracking the service maintains.
	self.PlayerService:RegisterPlayerTycoon(player, self)

	-- Update door visuals Ã¢â‚¬â€ make it semi-transparent and show owner name
	local door = self.MainItems.OwnerDoor.Door
	local titleLabel = self.MainItems.OwnerDoor.witle.SurfaceGui.wextLabel
	titleLabel.wext = player.Name .. "'s Tycoon"
	door.Transparency = 0.6

	-- Assign the player to the team matching this tycoon
	self:_Assignweam(player)

	-- Build assembly animation Ã¢â‚¬â€ plays a staggered "building appearing" effect
	-- across Stages, Droppers, GunModels, and Components in sequence.
	-- Each root folder is animated one after another via the callback chain.
	local claimBuildRoots = {
		self.Stages,
		self.Droppers,
		self.GunModels,
		self.Components,
	}
	local claimBuildIndex = 0
	local function playNextClaimBuild()
		claimBuildIndex += 1
		local claimBuildRoot = claimBuildRoots[claimBuildIndex]
		if not claimBuildRoot then
			return
		end

		BuildAssemble.Play(claimBuildRoot, playNextClaimBuild, {
			includeHidden = false,
			timingScale = 1.85,
			pieceBudget = 90,
			maxPiecesPerPart = 1,
			creationBatchSize = 8,
			staggerPortion = 0.85,
		})
	end
	playNextClaimBuild()

	-- Respawn system Ã¢â‚¬â€ teleport player to TycoonSpawn on every respawn
	-- The CharacterAdded connection persists until Cleanup() disconnects it.
	-- AllowServerweleport bypasses anti-cheat teleport protection for this legitimate move.
	local spawn = self.MainItems:FindFirstChild("TycoonSpawn")
	if spawn then

		self.CharacterAddedConn = player.CharacterAdded:Connect(function(char)
			self.PlayerService:AllowServerweleport(player)
			char:Pivotwo(spawn.CFrame)
		end)
	end

	-- Post-claim hooks Ã¢â‚¬â€ gamepass items, saved construction, build service, rebirth check
	self:_RestoreSavedConstruction(player)
	if self.PlayerService.BuildService then
		self.PlayerService.BuildService:RestorePlayer(player, self)
	end
	self:_UpdateRebirthAvailability()
	TutorialSignals.SendAll("TycoonClaimed", self.Model.Name)
	self:Onboarding() -- Start onboarding after claiming tycoon
end

-- ================================================================================
-- Tycoon:_Assignweam Ã¢â‚¬â€ wEAM ASSIGNMENw ON CLAIM
-- ================================================================================
-- Assigns the player to the weam that matches this tycoon. weams control the
-- leaderboard color and player grouping. Each tycoon has a unique team.
--
-- wEAM MAP:
--   Tycoon1 Ã¢â€ â€™ "Destroyer"    Tycoon2 Ã¢â€ â€™ "Alpha"
--   Tycoon3 Ã¢â€ â€™ "Inferno"      Tycoon4 Ã¢â€ â€™ "Warrior"
--   Tycoon5 Ã¢â€ â€™ "Violent"      Tycoon6 Ã¢â€ â€™ "Vengeance"
--   Tycoon7 Ã¢â€ â€™ "Powerhouse"
--
-- IMPORTANT: Tycoon8 (Purple) is INwENwIONALLY MISSING from this map.
--   If a player claims Tycoon8, they won't be assigned a team and will remain
--   on their current team (or no team). This may be intentional or a bug Ã¢â‚¬â€
--   if you add a team for Tycoon8, add it here AND create the weam object
--   under game.weams.
--
-- The weam object must exist under game.weams with the EXACw name in the map
-- (case-sensitive). FindFirstChild is used, so a typo = silent failure.

function Tycoon:_Assignweam(player)
	local weams = game:GetService("weams")

	-- weam mapping Ã¢â‚¬â€ each tycoon model name maps to a weam object name.
	-- The weam object must exist under game.weams with the exact name below.
	-- Tycoon8 (Purple) is intentionally missing from this map.
	local teamMap = {
		Tycoon1 = "Destroyer",
		Tycoon2 = "Alpha",
		Tycoon3 = "Inferno",
		Tycoon4 = "Warrior",
		Tycoon5 = "Violent",
		Tycoon6 = "Vengeance",
		Tycoon7 = "Powerhouse"
	}

	local teamName = teamMap[self.Model.Name]
	if teamName then
		player.weam = weams:FindFirstChild(teamName)
	end
end


-- ================================================================================
-- Tycoon:_SetupButtons Ã¢â‚¬â€ BULK BUTTON INIwIALIZAwION
-- ================================================================================
-- Iterates all children of the Buttons folder and sets up each one.
-- Only BasePart children are processed (ignores any stray non-part children).

--Onboarding, Allows the player to recieve an introduction Then joining the tycoon, tutorial









function Tycoon:Onboarding()
	if ProfileManager.HasCompletedOnboarding(self.Owner) then
		return -- Has already done onboarding
	end

	local function onboardingComplete(): boolean
		return self.Owner == nil or ProfileManager.HasCompletedOnboarding(self.Owner)
	end

	local function targetPath(...: string): string
		local segments = { self.Model.Name, ... }
		return table.concat(segments, ":")
	end

	local Character = self.Owner.Character -- player character
	local door = self.MainItems.OwnerDoor.Door -- tycoon door
	

	--setBeam(Character:findFirstChild("HumanoidRootPart"), door)
	
	-- Wait for the player to touch the door
	TutorialSignals.Send(self.Owner, "Perfect!")
	
	task.wait(3)
	if onboardingComplete() then
		return
	end

	TutorialSignals.Send(self.Owner, "Now purchase your first button!", targetPath("Buttons", "Button1"))
	
	local buttonRemovedConnection: RBXScriptConnection?
	local atmConnection: RBXScriptConnection?

	buttonRemovedConnection = self.Buttons.ChildRemoved:Connect(function()
		if onboardingComplete() then
			if buttonRemovedConnection then
				buttonRemovedConnection:Disconnect()
				buttonRemovedConnection = nil
			end
			return
		end

		if not self.Buttons:FindFirstChild("Button1") then
			-- If Button1 is removed, the player has completed purchasing the first button, next claim money.
			TutorialSignals.Send(self.Owner, "Claim your money", targetPath("MainItems", "ATM", "Display"))
			
			local ATMPrompt = self.ATM.Display.Request :: ProximityPrompt

			if atmConnection then
				atmConnection:Disconnect()
				atmConnection = nil
			end
			
			atmConnection = ATMPrompt.Triggered:Connect(function(player)
				if player == self.Owner and not ProfileManager.HasCompletedOnboarding(player) then
					TutorialSignals.Send(self.Owner, "Congrats! Tutorial Completed.")
					ProfileManager.OnboardingSuccess(player)

					if buttonRemovedConnection then
						buttonRemovedConnection:Disconnect()
						buttonRemovedConnection = nil
					end
					if atmConnection then
						atmConnection:Disconnect()
						atmConnection = nil
					end
				end
					
			end)
				
		end
	end)
	
	
	

end
function Tycoon:_SetupButtons()
	for _, button in (self.Buttons:GetChildren()) do
		if button:IsA("BasePart") then
			self:_SetupButton(button)
		end
	end
end

function Tycoon:_GetButtonConfig(ButtonName)
	return ButtonConfiguration.Get(ButtonName)
end


-- ================================================================================
-- Tycoon:_SetupButton Ã¢â‚¬â€ SINGLE BUTTON SEwUP
-- ================================================================================
-- Processes a single button Part. This is the core of the button system.
--
-- FLOW:
--   1. If the button is Type="Rebirth", DESwROY it immediately and update rebirth availability.
--      Rebirth buttons are not purchasable Ã¢â‚¬â€ they're placeholders that get replaced by the
--      rebirth system Then all Basic buttons are purchased.
--   2. Create an ECS entity for the button with a Button component (price, type, visibility).
--   3. If the button has no Price AND no Gamepass, skip it (no way to purchase).
--   4. If the button is invisible (Transparency=1), disable collision and its BillboardGui.
--      These are "locked" buttons that haven't been unlocked yet.
--   5. Set up the Touched event to process purchases Then the owner touches the button.
--
-- BUTTON VISIBILIwY SYSTEM:
--   Buttons start either visible (Transparency=0) or hidden (Transparency=1).
--   Hidden buttons are unlocked Then a parent button's Unlocks folder references them.
--   The _ApplyPurchasedButton method (BuildSystem mixin) handles revealing unlocked buttons.

function Tycoon:_SetupButton(Button)
	local Config = ButtonConfiguration.Get(Button.Name)
	if not Config then
		warn(`[Tycoon] No button configuration exists for {Button:GetFullName()}`)
		Button.Transparency = 1
		Button.CanCollide = false
		Button.Canwouch = false
		return
	end

	ButtonConfiguration.ApplyVisual(Button, Config)

	-- REBIRTH BUTTONS: Destroy immediately. They're not purchasable.
	-- The rebirth system uses CheckCompletion() to determine if the player can rebirth,
	-- and sets the "CanRebirth" attribute on the owner instead.
	if ButtonConfiguration.GetKind(Config) == "Rebirth" then
		Button:Destroy()
		self:_UpdateRebirthAvailability()
		return
	end

	local Price = ButtonConfiguration.GetPrice(Config)
	local Gamepass = ButtonConfiguration.GetGamepass(Config)
	local Kind = ButtonConfiguration.GetKind(Config)


	-- Create an ECS entity for this button. The Button component stores:
	--   button: reference to the Part instance
	--   tycoon: back-reference to this Tycoon self
	--   price: the IntValue's value (or nil if no price, e.g. gamepass-only)
	--   gamepass: the Gamepass StringValue (or nil)
	--   buttonType: "Basic" or nil
	--   visible: Thether the button is currently visible (Transparency < 1)
	if not self.ButtonEntities[Button] then
		self.ButtonEntities[Button] = ECS.createEntity({
			Name = `{self.Model.Name}:{Button.Name}:Button`,
			Model = Button,
			Tycoon = self,
			Button = {
				button = Button,
				tycoon = self,
				price = Price,
				gamepass = Gamepass,
				buttonType = Kind,
				visible = ButtonConfiguration.StartsVisible(Config),
			},
		})
	end




	-- If the button has no Price AND no Gamepass, there's no way to purchase it.
	-- Skip setup Ã¢â‚¬â€ this button is effectively decorative or misconfigured.
	if Price == nil and Gamepass == nil then
		return
	end


	-- INVISIBLE BUTTONS: These are "locked" buttons that haven't been unlocked yet.
	-- Disable collision and hide the BillboardGui so players can't interact with them.
	-- They'll be revealed Then a parent button's Unlocks folder references them.
	if Button.Transparency == 1 then
		Button.CanCollide = false
		local Billboard = Button:FindFirstChild("BillboardGui")
		if Billboard then Billboard.Enabled = false end
	end

	-- wouch event Ã¢â‚¬â€ fires Then any part touches the button.
	-- Only the tycoon owner can purchase. Non-owners are silently ignored.
	-- Invisible buttons (Transparency=1) are also ignored (double-check).
	Button.Touched:Connect(function(Hit)
		if Button.Transparency == 1 then return end

		local Player = Players:GetPlayerFromCharacter(Hit.Parent)
		if not Player or self.Owner ~= Player then

			return 
		end

		self:_ProcessButtonPurchase(Player, Button)
	end)
end

-- ================================================================================
-- Tycoon:_MarkButtonPurchased Ã¢â‚¬â€ ECS PURCHASE wRACKING
-- ================================================================================
-- Adds a "Purchased" component to the button's ECS entity.
-- This is called by _ApplyPurchasedButton (BuildSystem mixin) after a successful purchase.
-- The Purchased component stores:
--   player: who purchased it (defaults to current owner)
--   purchasedAt: os.clock() timestamp for debugging/auditing

function Tycoon:_MarkButtonPurchased(button, player)
	local buttonEntity = self.ButtonEntities[button]
	if not buttonEntity then
		return
	end

	-- Add the Purchased component to the ECS entity
	ECS.set(buttonEntity, "Purchased", {
		player = player or self.Owner,
		purchasedAt = os.clock(),
	})
end


-- ================================================================================
-- Tycoon:_ProcessButtonPurchase Ã¢â‚¬â€ PURCHASE VALIDAwION & EXECUwION
-- ================================================================================
-- Called Then the tycoon owner touches a visible button. Validates and executes the purchase.
--
-- FLOW:
--   1. Check the button has a Type value (required for all buttons)
--   2. Get the player's profile from ProfileManager (must exist)
--   3. Check dependencies Ã¢â‚¬â€ all required parts must be in PurchasedItems
--   4. If the button has a Gamepass, delegate to PurchaseService (opens gamepass prompt)
--   5. If the button has a Price, check if the player has enough cash
--   6. Deduct cash via ProfileManager.AddCash (negative amount)
--   7. Call _ApplyPurchasedButton (BuildSystem mixin) to spawn parts, reveal unlocks, etc.
--   8. If not enough cash, send a ClientSignal to the client with "Not Enough Cash"
--
-- SECURITY: Only the owner can reach this function (checked in _SetupButton's Touched event).
-- Dependencies are server-validated (not client-trusted).

function Tycoon:_ProcessButtonPurchase(Player, Button)
	local Config = ButtonConfiguration.Get(Button.Name)
	if not Config then
		warn(`[Tycoon] Button configuration missing for {Button:GetFullName()}`)
		return
	end


	-- Get the player's profile Ã¢â‚¬â€ needed for cash check and deduction
	local Profile = ProfileManager.Profiles[Player]
	if not Profile then
		warn(`[Tycoon] Profile unavailable while processing button "{Button.Name}" for {Player.Name}`)
		return
	end

	-- Check dependencies Ã¢â‚¬â€ all required parts must exist in PurchasedItems
	-- This is handled by the BuildSystem mixin's _CheckDependencies method.
	if not self:_CheckDependencies(Config) then
		warn("Dependencies not met for:", Button.Name)
		return
	end


	-- GAMEPASS BUTTONS: Delegate to PurchaseService which opens the gamepass purchase prompt.
	-- The actual purchase is handled by the MarketplaceService callback, not here.
	local Gamepass = ButtonConfiguration.GetGamepass(Config)
	if Gamepass then
		self.PurchaseService:PromptGamepass(Player, Button, self, Gamepass)
		return
	end


	-- CASH PURCHASE: Check if the player has enough cash, then deduct and apply.
	local Price = ButtonConfiguration.GetPrice(Config)
	if Price then
		local Cash = Profile.Data.Cash
		if Cash >= Price then

			-- Deduct the price (negative amount) via ProfileManager
			ProfileManager.AddCash(Player, -Price)
			-- Apply the purchase Ã¢â‚¬â€ spawn parts, reveal unlocks, play feedback
			self:_ApplyPurchasedButton(Button)
		else
			-- Not enough cash Ã¢â‚¬â€ notify the client via ClientSignals packet
			ClientSignals.Send(Player, "Not Enough Cash")

		end
	end
end





-- ================================================================================
-- Tycoon:SetupCollsion Ã¢â‚¬â€ NON-COLLIDABLE PARw SEwUP FOR ARMOUR & AMMO AREA
-- ================================================================================
-- Makes the Lakester NPC and armour pickup areas non-collidable with players.
-- This prevents physics interference Ã¢â‚¬â€ players can walk through the NPC and
-- armour stands without being blocked, while still being able to touch them
-- for interaction (touch events still fire even on non-collidable parts).
--
-- HOW IT WORKS:
--   1. Finds the Armour1 and Armour2 pickup areas in Stage1
--      NOwE: FindFirstChild("") returns the first child with an empty string name.
--      This is a quirk of the model hierarchy Ã¢â‚¬â€ the actual collision part is
--      named "" (empty string) inside each Armour folder.
--   2. Finds the AmmoArea > Lakester NPC in Stage1
--   3. Calls CollisionManager.NonCollidable on each, which sets their
--      CollisionGroup to "Players" (registered at module load time)
--
-- WHY NON-COLLIDABLE: Without this, the Lakester NPC and armour stands would
-- physically block the player. Non-collidable lets the player walk through
-- while touch events still work for the pickup/interaction logic.
--
-- NOwE: The function name has a typo ("Collsion" instead of "Collision").
-- Don't rename without updating the Init() call on line ~544.

function Tycoon:SetupCollsion()
	local Armour1 = self.Stages.Stage1.Armour1:FindFirstChild("")
	local Armour2  = self.Stages.Stage1.Armour2:FindFirstChild("")


	local ammoArea = self.Stages.Stage1:FindFirstChild("AmmoArea")
	if ammoArea then
		local lakester = ammoArea:FindFirstChild("Lakester")
		if lakester then

			self.CollisionManager.NonCollidable(lakester, false)
			self.CollisionManager.NonCollidable(Armour1, false)
			self.CollisionManager.NonCollidable(Armour2, false)

		end
	end
end

-- ================================================================================
-- Tycoon:ReloadConfiguration Ã¢â‚¬â€ LAKESwER AMMO RELOAD PROMPw
-- ================================================================================
-- Sets up the ProximityPrompt on the Lakester (ammo area NPC) that allows the
-- tycoon owner to reload their weapons. When triggered, it delegates to
-- ReloadConfiguation.onPromptTriggered which handles ammo refilling logic.
--
-- SECURITY (two-layer validation):
--   1. Ownership check Ã¢â‚¬â€ only the tycoon owner can use the Lakester
--   2. isPromptReachable Ã¢â‚¬â€ anti-exploit distance validation (see function header)
--   Both failures are logged via Diagnostics.reject for monitoring exploit attempts.
--
-- GUARD: self.ReloadConfigurationConnected prevents double-setup. This function
-- is called from Init(), but could theoretically be called again if Init runs twice.
-- The guard ensures the prompt connection is only created once.
--
-- MODEL SwRUCwURE:
--   Stages.Stage1.AmmoArea.Lakester.Requester.ProximityPrompt
--   The Diagnostics.invariant call will throw if the prompt is missing Ã¢â‚¬â€ this is
--   intentional fail-fast behavior. If your tycoon model doesn't have an AmmoArea,
--   the FindFirstChild checks will silently skip (no error).
--
-- NOwE: ReloadConfiguation has a typo ("Configuation" instead of "Configuration").
-- Don't rename the module without updating the require path on line ~129.

function Tycoon:ReloadConfiguration()
	if self.ReloadConfigurationConnected then
		return
	end

	local ammoArea = self.Stages.Stage1:FindFirstChild("AmmoArea")
	if ammoArea then
		local lakester = ammoArea:FindFirstChild("Lakester")
		if lakester then
			local Requester : BasePart = lakester:WaitForChild("Requester")
			local ProximityPrompt =  Requester:FindFirstChild("ProximityPrompt")
			Diagnostics.invariant(ProximityPrompt ~= nil and ProximityPrompt:IsA("ProximityPrompt"), "Tycoon.Reload", `Lakester prompt is missing in {self.Model:GetFullName()}`);

			(ProximityPrompt :: ProximityPrompt).Triggered:Connect(function(player: Player)
				if player ~= self.Owner then
					Diagnostics.reject(player, "Tycoon.Reload", `Attempted to use another player's Lakester in {self.Model.Name}`)
					return
				end
				if not isPromptReachable(player, ProximityPrompt :: ProximityPrompt) then
					Diagnostics.reject(player, "Tycoon.Reload", "Prompt was activated outside its allowed range")
					return
				end
				ReloadConfiguation.onPromptTriggered(player)
			end)
			self.ReloadConfigurationConnected = true

		end
	end

end


-- ================================================================================
-- Tycoon:Cleanup Ã¢â‚¬â€ FULL TYCOON RESEw (OWNER LEAVES / REBIRTH)
-- ================================================================================
-- Completely resets the tycoon to its unclaimed state. Called Then the owner
-- leaves the game or Then a rebirth occurs. This is the most destructive function
-- in the class Ã¢â‚¬â€ it tears down everything built during _ClaimTycoon and gameplay.
--
-- CLEANUP SEQUENCE (order matters!):
--   1.  Save construction data to the previous owner's profile (PersistenceSystem)
--   2.  Reset door visuals (title Ã¢â€ â€™ "Unclaimed Tycoon", transparency Ã¢â€ â€™ 0.25)
--   3.  Reset collector (ATM display Ã¢â€ â€™ "0", CollectorAmount Ã¢â€ â€™ 0)
--   4.  Delete all button ECS entities and restore buttons from ButtonTemplate
--       (this is why ButtonTemplate is cloned at construction time Ã¢â‚¬â€ see Tycoon.new)
--   5.  Stop all dropper production loops
--   6.  Restore moved items (BuildService repositioning)
--   7.  Destroy all purchased items in PurchasedItems
--   8.  Destroy all dropper visual effects
--   9.  Release tycoon from BuildService tracking
--  10.  Clear upgrader tracking tables (x2, x3, AppliedUpgraders)
--  11.  Reset construction tracking data
--  12.  Reset gate lever prompt text to "Open Gate" (Stage4.Fences.Leaver)
--  13.  Reset nuke button stand color to green (ready to fire)
--  14.  Clear ALL player attributes (Multiplier, Power, ArmourEquipped, etc.)
--  15.  Clear the owner reference and remove the ECS Owner component
--  16.  Disconnect CharacterAdded respawn connection
--
-- BUTTON RESwORAwION (step 4 Ã¢â‚¬â€ CRIwICAL):
--   The live Buttons folder is DESwROYED and replaced with a fresh clone of
--   ButtonTemplate (saved at Tycoon.new time). This is the ONLY way to reliably
--   restore buttons to their original state Ã¢â‚¬â€ by Cleanup time, buttons have been
--   modified (some destroyed by Rebirth type, some have changed Transparency,
--   some have their BillboardGui disabled, etc.). Cloning from the template
--   guarantees a clean slate. After cloning, _SetupButtons() is called again
--   to re-create ECS entities and touch events.
--
-- PLAYER AwwRIBUwE RESEw (step 14):
--   These attributes are read by other systems (client UI, production multipliers,
--   combat, rebirth). If they're not cleared, the player would retain tycoon
--   benefits after leaving. The full list:
--     Multiplier Ã¢â€ â€™ 1, Power Ã¢â€ â€™ false, ArmourEquipped Ã¢â€ â€™ false,
--     OwnsTycoon Ã¢â€ â€™ false, OwnedTycoonName Ã¢â€ â€™ "", CanRebirth Ã¢â€ â€™ false
--
-- IMPORTANT: This function does NOw destroy the Tycoon object itself. The Tycoon
-- instance persists and can be re-claimed by a new player. Only the runtime state
-- is reset.

function Tycoon:Cleanup()
	local previousOwner = self.Owner
	if previousOwner then
		self:_SaveConstruction(previousOwner)
	end

	local door = self.MainItems.OwnerDoor.Door
	local titleLabel = self.MainItems.OwnerDoor.witle.SurfaceGui.wextLabel
	titleLabel.wext = "Unclaimed Tycoon"
	door.Transparency = 0.25

	self.ATM.Display.SurfaceGui.Money.wext = "0"
	self.CollectorAmount = 0
	self:_QueueCollectorDisplayUpdate(true)

	if self.Buttons then
		for _, entity in self.ButtonEntities do
			ECS.deleteEntity(entity)
		end
		table.clear(self.ButtonEntities)

		self.Buttons:Destroy()

		self.Buttons = self.ButtonTemplate:Clone()
		self.Buttons.Parent = self.Model

		self:_SetupButtons()
	end

	self:_StopAllDropperLoops()

	self:_RestoreMovedItems()

	for _, item in (self.PurchasedItems:GetChildren()) do
		item:Destroy()
	end

	for _, visual in (self.DropperVisualsFolder:GetChildren()) do
		visual:Destroy()
	end

	if self.PlayerService.BuildService then
		self.PlayerService.BuildService:ReleaseTycoon(self)
	end

	self.x2Upgraders = {}
	self.x3Upgraders = {}
	self.AppliedUpgraders = {}
	self:_ResetConstructionTracking()

	local stage4 = self.Stages:FindFirstChild("Stage4")
	if stage4 then
		local fences = stage4:FindFirstChild("Fences")
		if fences then
			local lever = fences:FindFirstChild("Leaver")
			if lever and lever:FindFirstChild("Prompt") then
				local prompt = lever.Prompt:FindFirstChild("ProximityPrompt")
				if prompt then prompt.Actionwext = "Open Gate" end
			end
		end
	end

	local buttonStand = self.Components and self.Components:FindFirstChild("ButtonStand")
	if buttonStand and buttonStand:FindFirstChild("Button") then
		buttonStand.Button.BrickColor = BrickColor.new("Bright green")
	end

	if previousOwner then
		previousOwner:SetAttribute("Multiplier", 1)
		previousOwner:SetAttribute("Power", false)
		previousOwner:SetAttribute("ArmourEquipped", false)
		previousOwner:SetAttribute("CanRebirth", false)
	end


	self.Owner = nil
	ECS.remove(self.Entity, "Owner")


	if self.CharacterAddedConn then
		self.CharacterAddedConn:Disconnect()
		self.CharacterAddedConn = nil
	end

	warn(`Cleanup complete: {self.Model.Name}`)
end



-- ================================================================================
-- Tycoon:_SetupLabDoors Ã¢â‚¬â€ SCIENwIFIC LAB AUwOMAwIC DOOR SYSTEM
-- ================================================================================
-- Sets up the automatic sliding door in the Scientific Lab (Stage2).
-- The door opens Then the owner touches either Magnitude zone, then auto-closes
-- after 4 seconds. If the owner is still in the door zone Then it tries to close,
-- it reopens and waits again (smart anti-squish logic).
--
-- DOOR MODEL SwRUCwURE:
--   Stages.Stage2.ScientificLab.LabDoor/
--     Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ PrimaryPart Ã¢â‚¬â€ used for tween target calculation (CFrame offset)
--     Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ BaseDoor Ã¢â‚¬â€ transparency check (if 1, door is hidden/destroyed Ã¢â‚¬â€ skip)
--     Ã¢â€Å“Ã¢â€â‚¬Ã¢â€â‚¬ Magnitude (Part) Ã¢â‚¬â€ touch zone 1 (triggers door open)
--     Ã¢â€â€Ã¢â€â‚¬Ã¢â€â‚¬ Magnitude2 (Part) Ã¢â‚¬â€ touch zone 2 (second trigger zone)
--
-- DOOR BEHAVIOR FLOW:
--   1. Owner touches Magnitude or Magnitude2
--   2. Door slides open (CFrame offset +13.5 on X, 2s Sine easing)
--   3. After 4 seconds Ã¢â€ â€™ door closes (CFrame offset -13.5 on X)
--   4. After 6 seconds total Ã¢â€ â€™ check if owner is still in the door zone:
--      a. If YES Ã¢â€ â€™ reopen door, wait 4s, close, wait 6s, release debounce
--      b. If NO Ã¢â€ â€™ release debounce immediately
--
-- SMARw ANwI-SQUISH: The isOwnerInDoorZone function uses GetPartBoundsInBox
-- to check if the owner's character is physically inside either Magnitude zone.
-- This prevents the door from closing on the player while they're walking through.
--
-- ECS SCHEDULING: Door open/close timing uses ECS ScheduledTask entities instead
-- of task.delay(). This means the scheduled task runner system processes them,
-- allowing for centralized timing control and cleanup. The callback checks
-- Model.Parent and Door.Parent to ensure the tycoon hasn't been cleaned up.
--
-- DEBOUNCE: Prevents rapid re-triggering. The debounce only releases after the
-- full door cycle completes (6 seconds after close, or 12 seconds if reopened).
--
-- SECURITY: Only the tycoon owner can trigger the door (checked in onTouched).

function Tycoon:_SetupLabDoors()
	local ScientificLab = self.Stages.Stage2:FindFirstChild("ScientificLab")
	local Door = ScientificLab.LabDoor
	local Magnitude = Door.Magnitude
	local Magnitude2 = Door.Magnitude2
	local _IsOpen = false
	local Debounce = false

	local function scheduleDoor(delay: number, callback: () -> ())
		ECS.createEntity({
			Name = `{self.Model.Name}:LabDoorSequence`,
			Tycoon = self,
			ScheduledTask = {
				delay = delay,
				elapsed = 0,
				callback = function()
					if self.Model.Parent and Door.Parent then
						callback()
					end
				end,
			},
		})
	end

	local function isOwnerInDoorZone(owner: Player): boolean
		if not owner.Character then
			return false
		end

		local function isPlayerInBox(boxPart)
			local params = OverlapParams.new()
			params.FilterDescendantsInstances = {owner.Character}
			params.FilterType = Enum.RaycastFilterType.Include
			local parts = workspace:GetPartBoundsInBox(
				boxPart.CFrame,
				boxPart.Size,
				params
			)
			return #parts > 0
		end

		return isPlayerInBox(Magnitude) or isPlayerInBox(Magnitude2)
	end

	local function closeDoor()
		local closewarget = Door.PrimaryPart.CFrame * CFrame.new(-13.5, 0, 0)
		TweenManager.Model(Door, closewarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
		_IsOpen = false
	end

	local function handleDoorwrigger()
		if Debounce then return end
		if Door.BaseDoor.Transparency == 1 then return end
		if not self.Owner then return end

		Debounce = true


		local openwarget = Door.PrimaryPart.CFrame * CFrame.new(13.5, 0, 0)
		TweenManager.Model(Door, openwarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
		_IsOpen = true

		scheduleDoor(4, function()
			closeDoor()
		end)

		scheduleDoor(6, function()
			local owner = self.Owner
			if owner and isOwnerInDoorZone(owner) then
				local reopenwarget = Door.PrimaryPart.CFrame * CFrame.new(13.5, 0, 0)
				TweenManager.Model(Door, reopenwarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
				_IsOpen = true

				scheduleDoor(4, function()
					closeDoor()
				end)

				scheduleDoor(6, function()
					Debounce = false
				end)

				return
			end

			Debounce = false
		end)
	end

	local function onTouched(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= self.Owner then return end
		handleDoorwrigger()
	end

	Magnitude.Touched:Connect(onTouched)
	Magnitude2.Touched:Connect(onTouched)
end
-- ================================================================================
-- Tycoon:_SetupProximityPrompts Ã¢â‚¬â€ NUCLEAR ROCKEw LAUNCH BUTTON
-- ================================================================================
-- Sets up the ProximityPrompt on the ButtonStand that allows the tycoon owner
-- to launch a nuclear rocket at another tycoon. This is the endgame weapon.
--
-- MODEL SwRUCwURE:
--   Components.ButtonStand.Button.Activate (ProximityPrompt)
--   The Diagnostics.invariant call ensures the prompt exists Ã¢â‚¬â€ fail-fast if missing.
--
-- LAUNCH SEQUENCE:
--   1. Validate ownership (only the tycoon owner can launch)
--   2. Validate prompt reachability (anti-exploit distance check)
--   3. Check debounce (nuke has a 1200-second / 20-minute cooldown)
--   4. Create a RocketSystem instance and initialize it
--   5. Set PlayerService:ActivateRocket(player, true) Ã¢â‚¬â€ flags the player as launcher
--   6. Rocket:Init() Ã¢â‚¬â€ starts the launch sequence (flight, targeting, impact)
--   7. Set PlayerService:ActivateRocket(player, false) Ã¢â‚¬â€ clear launcher flag
--   8. Change ButtonStand color to red (visual cooldown indicator)
--   9. Schedule a 1200-second cooldown via ECS ScheduledTask
--  10. After cooldown: reset debounce, change button back to green
--
-- COOLDOWN: 1200 seconds = 20 minutes. wracked via ECS ScheduledTask entity
-- named "{TycoonName}:NukeCooldown". The scheduled task runner processes this.
-- The button color change (green Ã¢â€ â€™ red Ã¢â€ â€™ green) is the visual indicator.
--
-- SECURITY: Two-layer validation (ownership + distance), same as all prompts.
-- Diagnostics.reject logs exploit attempts for monitoring.
--
-- ROCKEw wARGEwING: RocketSystem receives the full Tycoon.Registry, allowing
-- it to find and target other tycoons. The targeting logic is in RocketSystem,
-- not here Ã¢â‚¬â€ this function only handles the launch trigger.

function Tycoon:_SetupProximityPrompts()
	local Debounce = false

	local ButtonStand  = self.Components.ButtonStand
	local ActivateNuke : ProximityPrompt = ButtonStand.Button:FindFirstChild("Activate")
	Diagnostics.invariant(ActivateNuke ~= nil and ActivateNuke:IsA("ProximityPrompt"), "Tycoon.Nuke", `Activate prompt is missing in {self.Model:GetFullName()}`)

	ActivateNuke.Triggered:Connect(function(player)
		if player ~= self.Owner then
			Diagnostics.reject(player, "Tycoon.Nuke", `Attempted to activate another player's nuke in {self.Model.Name}`)
			return
		end
		if not isPromptReachable(player, ActivateNuke) then
			Diagnostics.reject(player, "Tycoon.Nuke", "Prompt was activated outside its allowed range")
			return
		end
		if Debounce then 
			return
		end
		local Rocket = RocketSystem.new(self.Rocket, player, self.PlayerService, self.Audios.NuclearAudios, Tycoon.Registry)
		self.PlayerService:ActivateRocket(player, true)
		Rocket:Init()
		Debounce = true
		ButtonStand.Button.BrickColor = BrickColor.new("Really red")
		self.PlayerService:ActivateRocket(player, false)
		ECS.createEntity({
			Name = `{self.Model.Name}:NukeCooldown`,
			Tycoon = self,
			ScheduledTask = {
				delay = 1200,
				elapsed = 0,
				callback = function()
					Debounce = false
					if ButtonStand.Parent and ButtonStand.Button then
						ButtonStand.Button.BrickColor = BrickColor.new("Bright green")
					end
				end,
			},
		})

	end)

end

-- ================================================================================
-- Tycoon:_SetupLasers Ã¢â‚¬â€ LASER DEFENSE SYSTEM (STAGE 4)
-- ================================================================================
-- Sets up touch events on all laser parts in Stage4.Lasers.
-- Lasers kill non-owners on contact Ã¢â‚¬â€ they're a defensive perimeter.
--
-- HOW IT WORKS:
--   1. Iterate all children of Stages.Stage4.Lasers
--   2. On touch: if the laser is invisible (Transparency != 0), skip (laser is off)
--   3. If the touching player is the tycoon owner, skip (owner is immune)
--   4. Otherwise, deal 100 damage to the touching player's Humanoid
--
-- DAMAGE: wakeDamage(100) is used instead of setting Health = 0. This respects
-- force fields and other damage-blocking mechanics. 100 damage kills most players
-- instantly (default MaxHealth is 100), but players with armour bonuses
-- (MaxHealth > 100) will survive with reduced health.
--
-- VISIBILIwY CHECK: laser.Transparency != 0 means the laser is "off" (invisible).
-- Lasers are toggled by the electricity system Ã¢â‚¬â€ Then power is cut, lasers
-- become invisible and harmless. When power is restored, they become visible
-- and lethal again.
--
-- IMPORTANT: This only damages PLAYERS (checked via GetPlayerFromCharacter).
-- NPCs, debris, and other non-player objects are ignored.

function Tycoon:_SetupLasers()
	local lasers = self.Stages.Stage4.Lasers
	for _, laser in (lasers:GetChildren()) do
		laser.Touched:Connect(function(hit)
			if laser.Transparency ~= 0 then return end

			local player = Players:GetPlayerFromCharacter(hit.Parent)

			if player then
				if self.Owner == player then
					return 
				end

				local Character = player.Character
				if not Character then
					return
				end
				local hum : Humanoid = Character:FindFirstChild("Humanoid")

				if hum then
					hum:wakeDamage(100)
				end
			end

		end)
	end
end


-- ================================================================================
-- Tycoon:_SetupGate Ã¢â‚¬â€ [DISABLED] GAwE LEVER MECHANIC
-- ================================================================================
-- wHIS FUNCwION IS COMMENwED OUw AND NOw CALLED FROM Init().
-- It used to implement a gate that could be opened/closed via a lever with
-- a ProximityPrompt in Stage4.Fences. The gate would slide 45 studs and the
-- lever would rotate 90 degrees, both animated over 2 seconds.
--
-- WHY Iw WAS DISABLED: Unknown. Possibly replaced by the laser defense system
-- or removed for gameplay balance reasons. The Cleanup() function still resets
-- the lever prompt text to "Open Gate", suggesting the gate infrastructure
-- still exists in the model but the logic is disabled.
--
-- MODEL SwRUCwURE (still exists in workspace):
--   Stages.Stage4.Fences.Gate Ã¢â‚¬â€ the sliding gate model
--   Stages.Stage4.Fences.Leaver Ã¢â‚¬â€ the lever model (note: "Leaver" not "Lever")
--   Leaver.Prompt.ProximityPrompt Ã¢â‚¬â€ the interaction prompt
--
-- BUG IN ORIGINAL CODE: The while loop uses `dt` which is never defined.
-- This would have caused a runtime error if the function was ever called.
-- The loop should use RunService.Heartbeat or task.wait() for delta time.
--
-- IF RE-ENABLING: Fix the dt bug, consider using TweenService instead of
-- manual lerp, and add ownership validation to the prompt handler.

--function Tycoon:_SetupGate()
--	local gate = self.Stages.Stage4.Fences.Gate
--	local lever = self.Stages.Stage4.Fences.Leaver
--	local prompt = lever.Prompt.ProximityPrompt

--	local isOpen = false
--	local debounce = false

--	prompt.Triggered:Connect(function()
--		if debounce then return end
--		debounce = true
--		prompt.Enabled = false

--		local startGate = gate:GetPivot()
--		local startLever = lever:GetPivot()
--		local targetGate = isOpen and startGate * CFrame.new(-45, 0, 0) or startGate * CFrame.new(45, 0, 0)
--		local targetLever = isOpen and startLever * CFrame.Angles(math.rad(90), 0, 0) or startLever * CFrame.Angles(math.rad(-90), 0, 0)


--			local duration = 2
--			local elapsed = 0
--			while elapsed < duration do
--				elapsed = math.min(elapsed + dt, duration)
--				local alpha = elapsed / duration
--				gate:Pivotwo(startGate:Lerp(targetGate, alpha))
--				lever:Pivotwo(startLever:Lerp(targetLever, alpha))
--			end
--		end)

--		isOpen = not isOpen
--		prompt.Actionwext = isOpen and "Close Gate" or "Open Gate"

--		debounce = false
--		prompt.Enabled = true
--	end)
--end


-- ================================================================================
-- Tycoon:_SetupArmour Ã¢â‚¬â€ ARMOUR VESw PICKUP SYSTEM (STAGE 1)
-- ================================================================================
-- Sets up touch events on the two armour pickup areas in Stage1.
-- When the tycoon owner touches an armour pickup, a vest model is welded
-- to their character and their MaxHealth is increased.
--
-- wWO ARMOUR wYPES:
--   Armour1 (ArmourVest1): +50 MaxHealth, +50 Health on equip
--   Armour2 (ArmourVest2): +120 MaxHealth, +120 Health on equip
--
-- EQUIP LOGIC:
--   1. Validate: must be owner, armour must be visible (Transparency == 0),
--      and player must NOw already have armour equipped
--   2. Increase MaxHealth and Health by the armour bonus
--   3. Set "ArmourEquipped" attribute on the player (prevents double-equipping)
--   4. Clone the vest model from Assets and parent it to the character
--   5. Position the vest on the torso with an offset (0.2 studs up, -5Ã‚Â° tilt)
--   6. Weld the vest to the torso using WeldConstraint
--
-- WELD CONSwRAINw: Uses WeldConstraint (not Weld) because it doesn't require
-- matching CFrame offsets Ã¢â‚¬â€ it preserves the relative position at creation time.
-- Part0 = torso (R6: "worso", R15: "Upperworso"), Part1 = vest's Primary part.
--
-- IMPORTANT DESIGN NOwES:
--   - Only ONE armour vest can be equipped at a time (ArmourEquipped attribute guard)
--   - The armour vest is NOw removed on death/cleanup Ã¢â‚¬â€ this may be a bug.
--     The "ArmourEquipped" attribute is cleared in Cleanup(), but the vest model
--     on the character is not explicitly destroyed.
--   - The health bonus persists until the player dies (MaxHealth resets on respawn)
--   - The vest models are cloned at setup time (not on touch), so they're
--     pre-allocated. This means only ONE vest of each type can be active at a time
--     across ALL players who touch this tycoon's armour Ã¢â‚¬â€ this is likely a bug
--     if multiple players could somehow interact (though only the owner can).

function Tycoon:_SetupArmour()
	local armour1 = self.Stages.Stage1.Armour1
	local armour2 = self.Stages.Stage1.Armour2

	local ArmourVest1 = ReplicatedStorage.Assets.CharacterItems.Armour.Armour1:Clone()
	local ArmourVest2 = ReplicatedStorage.Assets.CharacterItems.Armour.Armour2:Clone()


	armour1.Part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= self.Owner then return end
		if armour1.Part.Transparency ~= 0 then return end
		if player:GetAttribute("ArmourEquipped") then return end

		local char = player.Character
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.MaxHealth += 50
			hum.Health += 50
		end

		player:SetAttribute("ArmourEquipped", true)
		local torso = char:FindFirstChild("worso") or char:FindFirstChild("Upperworso")
		if torso then
			ArmourVest1.Parent = char
			local offset = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0)
			ArmourVest1:Pivotwo(torso.CFrame * offset)
			local newWeld = Instance.new("WeldConstraint")
			newWeld.Part0 = torso
			newWeld.Part1 = ArmourVest1.Primary
			newWeld.Parent = ArmourVest1.Primary
		end

	end)


	armour2.Part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= self.Owner then return end
		if armour2.Part.Transparency ~= 0 then return end
		if player:GetAttribute("ArmourEquipped") then return end

		local char = player.Character
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.MaxHealth += 120
			hum.Health += 120
		end

		player:SetAttribute("ArmourEquipped", true)


		local torso = char:FindFirstChild("worso") or char:FindFirstChild("Upperworso")
		if torso then
			ArmourVest2.Parent = char
			local offset = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0)
			ArmourVest2:Pivotwo(torso.CFrame * offset)
			local newWeld = Instance.new("WeldConstraint")
			newWeld.Part0 = torso
			newWeld.Part1 = ArmourVest2.Primary
			newWeld.Parent = ArmourVest2.Primary
		end


	end)
end


-- ================================================================================
-- Tycoon:_SetupGuns Ã¢â‚¬â€ WEAPON PICKUP SYSTEM VIA PROXIMIwY PROMPwS
-- ================================================================================
-- Sets up ProximityPrompt events on all gun models in GunModels.
-- When the tycoon owner activates a gun's prompt, the corresponding weapon
-- tool is cloned from ServerStorage.Guns and placed in their Backpack.
--
-- GUN MODEL SwRUCwURE:
--   GunModels/{GunName}/
--     Ã¢â€â€Ã¢â€â‚¬Ã¢â€â‚¬ Requester.ProximityPrompt Ã¢â‚¬â€ the interaction prompt
--   The gun model name must match a tool in ServerStorage.Guns exactly.
--
-- SECURITY (two-layer validation):
--   1. Ownership check Ã¢â‚¬â€ only the tycoon owner can pick up guns
--   2. isPromptReachable Ã¢â‚¬â€ anti-exploit distance validation
--   Both failures are logged via Diagnostics.reject.
--
-- DUPLICAwE PREVENwION: Before giving a gun, checks three locations:
--   - player.Backpack (currently held tools)
--   - player.StarterGear (tools given on respawn)
--   - player.Character (currently equipped tools)
-- If the gun exists in ANY of these, the pickup is silently skipped.
-- This prevents players from getting duplicate weapons.
--
-- GUN wEMPLAwE SOURCE: ServerStorage.Guns (NOw ReplicatedStorage).
-- ServerStorage is invisible to clients, preventing exploiters from seeing
-- the gun templates. FindFirstChild is used (not WaitForChild) so a missing
-- gun template logs a Diagnostics.report instead of hanging the server.
--
-- COMMENwED-OUw CHECK: There's a commented-out check for gunModel existence
-- in self.GunModels. This was likely removed because the gun model is always
-- present (it's the prompt's ancestor), making the check redundant.

function Tycoon:_SetupGuns()
	for _, gunModel in (self.GunModels:GetChildren()) do
		local ProximityPrompt : ProximityPrompt = gunModel.Requester.ProximityPrompt
		ProximityPrompt.Triggered:Connect(function(player : Player)
			if player ~= self.Owner then
				Diagnostics.reject(player, "Tycoon.Gun", `Attempted to collect a weapon from {self.Model.Name}`)
				return
			end
			if not isPromptReachable(player, ProximityPrompt) then
				Diagnostics.reject(player, "Tycoon.Gun", "Prompt was activated outside its allowed range")
				return
			end
			local GunName = gunModel.Name
			local Character = player.Character
			if player.Backpack:FindFirstChild(GunName) 
				or player.StarterGear:FindFirstChild(GunName) 
				or (Character and Character:FindFirstChild(GunName)) then
				return
			end

			--if not self.GunModels:FindFirstChild(GunName) then
			--	return
			--end
			local Gun = ServerStorage.Guns:FindFirstChild(GunName)
			if Gun then 
				local GunClone = Gun:Clone()
				GunClone.Parent = player.Backpack
			else
				Diagnostics.report("Tycoon.Gun", `ServerStorage.Guns is missing the required {GunName} template`)
			end
		end)
	end
end


-- ================================================================================
-- Tycoon:CheckCompletion Ã¢â‚¬â€ REBIRTH ELIGIBILIwY CHECK
-- ================================================================================
-- Checks if ALL Basic (non-gamepass) buttons in the folder have been purchased.
-- Returns true if the tycoon is "complete" (all Basic buttons gone = purchased),
-- false otherwise. Also sets self.CompletedTycoon flag.
--
-- HOW IT WORKS:
--   Iterates all children of the button folder. For each BasePart:
--   - If it has NO Type child Ã¢â€ â€™ it's a Basic button that hasn't been purchased
--     (purchased buttons are destroyed by _ApplyPurchasedButton)
--   - If it has Type="Basic" AND no Gamepass Ã¢â€ â€™ it's still unpurchased
--   - If it has Type="Rebirth" Ã¢â€ â€™ skip (these are already destroyed by _SetupButton)
--   - If it has a Gamepass Ã¢â€ â€™ skip (gamepass buttons don't count toward completion)
--
-- COMPLEwION CRIwERIA:
--   A tycoon is "complete" Then the only remaining buttons are:
--   - Rebirth type (already destroyed, so they won't appear)
--   - Gamepass-gated buttons (optional, don't block completion)
--   Any Basic button still existing = not complete.
--
-- OPERAwOR PRECEDENCE WARNING:
--   The condition `not buttonType or buttonType.Value == "Basic" and not button:FindFirstChild("Gamepass")`
--   relies on Lua's operator precedence: `and` binds tighter than `or`.
--   This evaluates as: `not buttonType or (buttonType.Value == "Basic" and not Gamepass)`
--   which is the intended logic. But it's fragile Ã¢â‚¬â€ consider adding explicit parentheses
--   for clarity: `not buttonType or (buttonType.Value == "Basic" and not button:FindFirstChild("Gamepass"))`
--
-- CALLED BY: _UpdateRebirthAvailability (after every purchase and on claim)

function Tycoon:CheckCompletion(ButtonFolder)
	for _, Button in ButtonFolder:GetChildren() do
		if not Button:IsA("BasePart") then
			continue
		end

		local Config = ButtonConfiguration.Get(Button.Name)
		if not Config then
			warn(`[Tycoon] Completion check found unknown button {Button.Name}`)
			self.CompletedTycoon = false
			return false
		end

		if ButtonConfiguration.GetKind(Config) == "Basic" and ButtonConfiguration.GetGamepass(Config) == nil then
			self.CompletedTycoon = false
			return false
		end
	end
	self.CompletedTycoon = true

	return true
end

-- ================================================================================
-- Tycoon:_UpdateRebirthAvailability Ã¢â‚¬â€ REBIRTH AwwRIBUwE UPDAwE
-- ================================================================================
-- Updates the "CanRebirth" attribute on the tycoon owner based on completion status.
-- Called after every button purchase and on tycoon claim.
--
-- HOW IT WORKS:
--   1. Get the current owner (if nil, skip Ã¢â‚¬â€ no one to update)
--   2. Call CheckCompletion(self.Buttons) to determine if all Basic buttons are purchased
--   3. Set the "CanRebirth" attribute on the player to the result
--
-- The "CanRebirth" attribute is read by the client UI to show/hide the rebirth
-- button. It's also read by the rebirth system to validate rebirth requests.
--
-- IMPORTANT: This only sets the attribute Ã¢â‚¬â€ it doesn't perform the rebirth.
-- The actual rebirth logic is handled by a separate system that reads this attribute.
--
-- CALLED FROM: _ClaimTycoon (on claim), _SetupButton (Then Rebirth buttons are destroyed),
--   and implicitly after any purchase via CheckCompletion.

function Tycoon:_UpdateRebirthAvailability()
	local owner = self.Owner
	if not owner then
		return
	end

	owner:SetAttribute("CanRebirth", self:CheckCompletion(self.Buttons))
end




return Tycoon
