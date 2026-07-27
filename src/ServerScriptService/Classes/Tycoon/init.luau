
--[[
	Tycoon class

	This module owns the server-side lifecycle for each physical tycoon model in Workspace.Tycoons.
	Each model gets one Tycoon object, which coordinates ownership, button purchases, production,
	electricity, persistence, weapons, armour, reload prompts, nukes, rebirth checks, and cleanup.

	Architecture:
	- Focused systems in Systems/ are mixed into this class at load time.
	- ECS stores shared runtime entities such as owners, buttons, scheduled tasks, and rocket state.
	- ProfileManager owns persistent data; this class does not write directly to DataStores.
	- PlayerRuntimeState owns fast server-memory player flags such as armour and rebirth readiness.

	Expected model layout:
	- MainItems: OwnerDoor, ATM, TycoonSpawn, gamepass items, and permanent interactables.
	- Buttons: purchase buttons configured by Configuration/ButtonConfiguration.
	- PurchasedItems: runtime folder where purchased builds are placed.
	- Stages, Droppers, GunModels: build roots used by BuildSystem and BuildAssemble.
	- Components: optional rocket/button-stand models.
	- Audios: optional tycoon-specific sounds.

	Important invariants:
	- Required folders intentionally use WaitForChild because a missing folder is a broken tycoon.
	- Optional folders use FindFirstChild and are guarded at call sites.
	- Prompt handlers validate ownership and distance on the server before granting rewards.
	- Cleanup resets the same Tycoon object so the physical model can be claimed again.
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

-- Used to create entities for: tycoon itself, each button, scheduled tasks (lab doors, nuke cooldown),
-- projectiles, and more. Components defined in ReplicatedStorage.ECS include:
--   Owner, Button, Purchased, ScheduledTask, RocketFlight, BuildItem, Reveal, etc.
-- Other systems (e.g. a scheduled task runner) iterate ECS queries to process tycoon state.
local ECS = require(ReplicatedStorage.ECS)

-- Manages rocket flight, targeting, impact effects, and launch session state (launcher/defender).
local RocketSystem = require(ServerScriptService.Classes.Tycoon.Systems.Rocket)

-- and by ProductionSystem for dropper animations. Wraps TweenService with model-awareness.
local TweenManager = require(ReplicatedStorage.Modules.TweenManager) :: any

-- Provides: Profiles[player] for reading data, AddCash() for deducting/adding currency,
-- and construction data storage for the PersistenceSystem mixin.
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

-- Manages ammo compatibility checks, tool interactions, and reload prompt processing.
-- without updating this require path.
local ReloadConfiguation = require(script.Systems.ReloadConfig)

-- 8 themes: White, Blue, Black, Green, Grey, Red, Yellow, Purple.
-- Applied to parts tagged with CollectionService tags ("Primary", "Secondary", "Accent").
local ColorConfiguration = require(script.Configuration.ColorConfiguration)
local ButtonConfiguration = require(script.Configuration.ButtonConfiguration)

--   _BuildTemplateCache:  Pre-caches all build part templates from Stages/Droppers/etc.
--                         PurchasedItems, plays visual feedback, reveals unlock buttons.
--   _CheckDependencies:   Validates that all required parts exist in PurchasedItems.
--   _ResetConstructionTracking: Clears purchase tracking data (used in Cleanup).
local BuildSystem = require(script.Systems.BuildSystem)

-- Plays a staggered assembly animation across Stages, Droppers, GunModels, and Components.
-- Used in _ClaimTycoon to give a satisfying "building appearing" effect on first claim.
local BuildAssemble = require(ServerScriptService.Utilities.BuildAssemble)

--   .invariant(condition, context, message): Asserts a condition, logs error if false.
--   .reject(player, context, message): Logs when a player fails an authorization check.
--   .report(context, message): Logs a general error/issue.
-- Used throughout for security validation (prompt reachability, ownership checks).
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)


local CollectorSystem = require(script.Systems.CollectorSystem)


local ProductionSystem = require(script.Systems.ProductionSystem)


local ElectricitySystem = require(script.Systems.ElectricitySystem)


local PersistenceSystem = require(script.Systems.PersistenceSystem)


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

--
-- WHY THIS EXISTS:
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

-- all tycoons (e.g. for nuke targeting). Key = Model, Value = Tycoon self.
Tycoon.Registry = {}

-- _ResetConstructionTracking, _PlayPurchaseFeedback, _RestoreMovedItems
BuildSystem(Tycoon)

-- _QueueCollectorDisplayUpdate, _FlushCollectorDisplay
-- Deps: ProfileManager (for cash reads/writes), ClientSignals (for client feedback)
CollectorSystem(Tycoon, {
	ProfileManager = ProfileManager,
	ClientSignals = ClientSignals,
})

-- _SetupAmmoArea, getNumericMultiplier
-- Deps: TweenService (dropper anims), CollectionService (tag queries), Cleanup (temp VFX)
ProductionSystem(Tycoon, {
	TweenService = TweenService,
	CollectionService = CollectionService,
	Cleanup = Cleanup,
})

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

-- _RestoreMovedItems, getConstructionData
-- Deps: ProfileManager (for reading/writing construction data to player profiles)
PersistenceSystem(Tycoon, {
	ProfileManager = ProfileManager,
})


-- that happens in :Init(). The constructor only stores references and sets up the instance table.
--
-- PARAMETERS:

-- IMPORTANT: The tycoon model MUST have these children or the constructor will hang:
--   MainItems, Values, Stages, Buttons, PurchasedItems, Droppers, GunModels

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

	-- These are NOT Roblox services; they're game-specific service modules.
	self.PlayerService = playerService
	self.PurchaseService = purchaseService
	self.RagdollModule = ragdollModule
	self.CollisionManager = collisionManager

	-- that are needed before any parts are configured.
	collisionManager.Initialize()


	-- These are the main organizational folders inside the tycoon model.
	-- FindFirstChild is used for optional folders (Components, Audios, DropperVisuals).

	self.MainItems = tycoonModel:WaitForChild("MainItems") :: Folder       -- OwnerDoor, Conveyor, ATM, TycoonSpawn, GamepassItems
	self.Stages = tycoonModel:WaitForChild("Stages") :: Folder               -- Stage1-4, Starting point
	self.Buttons = tycoonModel:WaitForChild("Buttons") :: Folder           -- All purchasable button Parts
	self.PurchasedItems = tycoonModel:WaitForChild("PurchasedItems") :: Folder -- Runtime: purchased build parts parented here
	self.Droppers = tycoonModel:WaitForChild("Droppers") :: Folder         -- Dropper models (NormalDropper1, GoldenDropper, etc.)
	self.GunModels = tycoonModel:WaitForChild("GunModels") :: Folder       -- Weapon pickup models (M4A1, AK-47, etc.)

	self.Components = tycoonModel:FindFirstChild("Components") :: Folder    -- Rocket, ButtonStand, RocketConstruction
	self.Audios = tycoonModel:FindFirstChild("Audios") :: Folder           -- PowerOut, NuclearAudios, Miscellaneous

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
	self.CharacterAddedConn = nil :: RBXScriptConnection?

	self.ATM = self.MainItems:WaitForChild("ATM")

	-- CollectorAmount tracks the accumulated cash in the collector.
	-- This is the "banked" cash that hasn't been picked up yet.
	-- Updated by CollectorSystem when dropper items touch the collector.
	self.CollectorAmount = 0

	-- ================================================================================
	-- STATE TRACKING TABLES
	-- ================================================================================

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
	-- ASSET REFERENCES (from Assets)
	-- ================================================================================

	-- Armour1: +50 MaxHealth, Armour2: +120 MaxHealth. Only one can be equipped at a time.
	self.ArmourVest1 = Assets.CharacterItems.Armour.Armour1
	self.ArmourVest2 = Assets.CharacterItems.Armour.Armour2

	self.NPC_IdleAnimation = Assets:WaitForChild("Animations").NPC_Idle

	self.Activation = Assets["Visual Effects"].Activation
	self.VisualEffects = VisualEffects

	self.Rocket = self.Components.Rocket

	-- if already set up. This is important because some systems (PersistenceSystem) might
	-- trigger re-initialization paths.
	self.IsSetup = false

	-- ================================================================================
	-- BUTTON TEMPLATE (CRITICAL FOR CLEANUP)
	-- ================================================================================
	-- We clone the entire Buttons folder at construction time and parent it to nil (hidden).
	-- This is the "clean" backup. When Cleanup() runs, the live Buttons folder is destroyed
	-- and replaced with a fresh clone of this template. This is how buttons get restored
	-- to their original state (unpurchased, visible/hidden as configured).
	--
	-- WHY CLONE AT CONSTRUCTION, NOT CLEANUP?
	--   Because by Cleanup time, the live Buttons folder has been modified (parts destroyed,
	--   values changed, etc.). We need the ORIGINAL state, which only exists at init time.
	self.ButtonTemplate  = self.Buttons:Clone() 
	self.ButtonTemplate.Parent = nil
	for _, button in self.ButtonTemplate:GetChildren() do
		if button:IsA("BasePart") then
			ButtonConfiguration.RemoveInstanceMetadata(button)
		end
	end

	-- Checked by CheckCompletion(), which is called after every purchase and on rebirth update.
	self.CompletedTycoon = false :: boolean

	return self
end







-- ================================================================================
-- ================================================================================
-- Called once after Tycoon.new(). Sets up all systems in the correct order.
-- The order matters because later systems may depend on earlier ones:
--
--

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
	self:SetupCollision()
	--self:_SetupGamepassTextAnimation()
	self:_SetupLabDoors()
	self:_SetupProximityPrompts()
	self:ReloadConfiguration()
	self:SetupTeleportation()
	
	
	-- this is done outside onboarding, since this message will be produced before claim
end

-- ================================================================================
-- ================================================================================
-- Applies the tycoon's color palette to all tagged parts in Stages and GunModels.
--
-- HOW IT WORKS:
--   1. Looks up the tycoon's name in TYCOON_STAGE_PALETTES to get Primary/Secondary/Accent colors.
--   2. Iterates ALL descendants of Stages and GunModels.
--   3. For each BasePart, checks CollectionService tags ("Primary", "Secondary", "Accent").
--   4. Sets part.Color to the matching palette color.
--
-- TAGGING PARTS:
--   To color a part, add a CollectionService tag matching one of the 3 palette slots.
--   The first matching tag wins (break after setting).
--
-- GUN MODELS COLORING:
--   Gun models have two levels of coloring:
--   This handles both structured and flat gun model hierarchies.

function Tycoon:ApplyColors()
	local palette: StagePalette? = TYCOON_STAGE_PALETTES[self.Model.Name]
	if not palette then
		warn(`[Tycoon] No stage palette configured for "{self.Model.Name}"`)
		return
	end

	local tagColors: {[string]: Color3} = {
		Primary = palette.Primary,
		Secondary = palette.Secondary,
		Accent = palette.Accent,
	}

	-- Color all tagged BaseParts in the Stages folder (build parts, walls, floors, etc.)
	for _, descendant in (self.Stages:GetDescendants()) do -- building
		if not descendant:IsA("BasePart") then
			continue
		end

		for tagName, color in (tagColors) do
			if CollectionService:HasTag(descendant, tagName) then
				descendant.Color = color
				break
			end
		end
	end



	-- Some gun models have a Folder named "Structure" containing the colored parts.
	-- This is for guns with a more complex hierarchy (e.g. display stands + gun body).
	for _, descendant in self.GunModels:GetDescendants() do

		if descendant:IsA("Folder") and descendant.Name == "Structure" then
			for _, BasePart : BasePart in descendant:GetChildren() do
				for tagName, color in (tagColors) do
					if CollectionService:HasTag(BasePart, tagName) then
						BasePart.Color = color
						break
					end

				end
			end
		end


	end


	-- For simpler gun models There the colored parts are direct children.
	for _, descendant in self.GunModels:GetChildren() do

		for _,  BasePart : BasePart  in descendant:GetChildren() do

			for tagName, color in (tagColors) do


				if CollectionService:HasTag(BasePart, tagName) then
					BasePart.Color = color
					break

				end
			end
		end


	end

end



-- ================================================================================
-- COLLISION GROUP REGISTRATION (module-level)
-- ================================================================================
-- Registers the "Players" collision group at module load time (before any Tycoon is created).
-- This group is used by CollisionManager.NonCollidable to make parts (Lakester NPC,
-- armour pickup areas) non-collidable with players, preventing physics interference.
--
-- WHY MODULE-LEVEL: This runs once when the script is first required, not per-tycoon.
-- The collisionGroupExists check prevents double-registration errors if the module
-- is required multiple times (e.g. hot-reloading during development).
--
-- NOTE: If you add new collision groups (e.g. "NPC", "Vehicle"), register them here
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
-- who touches it can claim. The PlayerService:OwnsTycoon check is the only guard.
--
-- DOOR MODEL STRUCTURE:
--   MainItems.OwnerDoor/

function Tycoon:_SetupDoor()
	local door = self.MainItems.OwnerDoor:WaitForChild("Door")


	door.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		if self.PlayerService:OwnsTycoon(player) then return end

		if not self.Owner then
			self:_ClaimTycoon(player)
		end
	end)
end


-- ================================================================================
-- ================================================================================
-- Called when a player successfully claims an unowned tycoon. This is the most
-- needs to start playing.
--
-- CLAIM SEQUENCE (in order):
--   1. Store the owner Player reference
--   2. Set ECS "Owner" component on the tycoon entity
--   3. Register ownership via PlayerService (updates PlayerService runtime ownership)
--   4. Update the door: transparency + title text with player name
--   5. Assign the player to the matching team (via _AssignTeam)
--   6. Play the BuildAssemble animation (staggered build appearance)
--   7. Set up respawn at TycoonSpawn (CharacterAdded connection)
--   8. Fire PurchaseService:OnTycoonClaimed (handles gamepass items, etc.)
--  10. Restore BuildService items (player-moved objects from previous session)
--  11. Update rebirth availability (check if all Basic buttons are purchased)
--
-- BUILD ASSEMBLE ANIMATION:
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
--   PlayerService:AllowServerTeleport is called before PivotTo to bypass anti-teleport
--   protections that might block server-side character movement.
--
-- check happens in _SetupDoor before calling this. Don't call this directly.

function Tycoon:_ClaimTycoon(player)
	print("Claimed by:", player.Name)

	self.Owner = player
	ECS.set(self.Entity, "Owner", player)


	self.PlayerService:RegisterPlayerTycoon(player, self)

	local door = self.MainItems.OwnerDoor.Door
	local titleLabel = self.MainItems.OwnerDoor.Title.SurfaceGui.TextLabel
	titleLabel.Text = player.Name .. "'s Tycoon"
	door.Transparency = 0.6

	-- Assign the player to the team matching this tycoon
	self:_AssignTeam(player)

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

	-- The CharacterAdded connection persists until Cleanup() disconnects it.
	-- AllowServerTeleport bypasses anti-cheat teleport protection for this legitimate move.
	local spawn = self.MainItems:FindFirstChild("TycoonSpawn")
	if spawn then

		self.CharacterAddedConn = player.CharacterAdded:Connect(function(char)
			self.PlayerService:AllowServerTeleport(player)
			char:PivotTo(spawn.CFrame)
		end)
	end

	self:_RestoreSavedConstruction(player)
	if self.PlayerService.BuildService then
		self.PlayerService.BuildService:RestorePlayer(player, self)
	end
	self:_UpdateRebirthAvailability()
	TutorialSignals.SendAll("TycoonClaimed", self.Model.Name)
	self:Onboarding() -- Start onboarding after claiming tycoon
end

-- ================================================================================
-- ================================================================================
-- Assigns the player to the team that matches this tycoon. Teams control the
-- leaderboard color and player grouping. Each tycoon has a unique team.
--
-- TEAM MAP:
--
-- IMPORTANT: Tycoon8 (Purple) is INTENTIONALLY MISSING from this map.
--   If a player claims Tycoon8, they won't be assigned a team and will remain
--   if you add a team for Tycoon8, add it here AND create the team object
--   under game.Teams.
--
-- The team object must exist under game.Teams with the EXACT name in the map
-- (case-sensitive). FindFirstChild is used, so a typo = silent failure.

function Tycoon:_AssignTeam(player)
	local teams = game:GetService("Teams")

	-- The team object must exist under game.Teams with the exact name below.
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
		player.Team = teams:FindFirstChild(teamName)
	end
end


-- ================================================================================
-- ================================================================================
-- Iterates all children of the Buttons folder and sets up each one.
-- Only BasePart children are processed (ignores any stray non-part children).

-- Onboarding introduces the player after they claim a tycoon.









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
-- ================================================================================
-- Processes a single button Part. This is the core of the button system.
--
-- FLOW:
--   1. If the button is Type="Rebirth", DESTROY it immediately and update rebirth availability.
--      rebirth system when all Basic buttons are purchased.
--   2. Create an ECS entity for the button with a Button component (price, type, visibility).
--   3. If the button has no Price AND no Gamepass, skip it (no way to purchase).
--   4. If the button is invisible (Transparency=1), disable collision and its BillboardGui.
--      These are "locked" buttons that haven't been unlocked yet.
--   5. Set up the Touched event to process purchases when the owner touches the button.
--
-- BUTTON VISIBILITY SYSTEM:
--   Buttons start either visible (Transparency=0) or hidden (Transparency=1).
--   Hidden buttons are unlocked when a parent button's Unlocks folder references them.
--   The _ApplyPurchasedButton method (BuildSystem mixin) handles revealing unlocked buttons.

function Tycoon:_SetupButton(Button)
	local Config = ButtonConfiguration.Get(Button.Name)
	if not Config then
		warn(`[Tycoon] No button configuration exists for {Button:GetFullName()}`)
		Button.Transparency = 1
		Button.CanCollide = false
		Button.CanTouch = false
		return
	end

	ButtonConfiguration.ApplyVisual(Button, Config)

	-- REBIRTH BUTTONS: Destroy immediately. They're not purchasable.
	-- The rebirth system uses CheckCompletion() to determine if the player can rebirth,
	-- and updates the owner runtime rebirth flag through PlayerRuntimeState.
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
	if Price == nil and Gamepass == nil then
		return
	end


	-- INVISIBLE BUTTONS: These are "locked" buttons that haven't been unlocked yet.
	-- Disable collision and hide the BillboardGui so players can't interact with them.
	-- They'll be revealed when a parent button's Unlocks folder references them.
	if Button.Transparency == 1 then
		Button.CanCollide = false
		local Billboard = Button:FindFirstChild("BillboardGui")
		if Billboard then
			 Billboard.Enabled = false
			 end
	end

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
-- ================================================================================
-- Called when the tycoon owner touches a visible button. Validates and executes the purchase.
--
-- FLOW:
--   1. Check the button has a Type value (required for all buttons)
--   2. Get the player's profile from ProfileManager (must exist)
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


	local Profile = ProfileManager.Profiles[Player]
	if not Profile then
		warn(`[Tycoon] Profile unavailable while processing button "{Button.Name}" for {Player.Name}`)
		return
	end

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
			self:_ApplyPurchasedButton(Button)
		else
			ClientSignals.Send(Player, "Not Enough Cash")

		end
	end
end





-- ================================================================================
-- ================================================================================
-- Makes the Lakester NPC and armour pickup areas non-collidable with players.
-- armour stands without being blocked, while still being able to touch them
-- for interaction (touch events still fire even on non-collidable parts).
--
-- HOW IT WORKS:
--   1. Finds the Armour1 and Armour2 pickup areas in Stage1
--      NOTE: FindFirstChild("") returns the first child with an empty string name.
--      named "" (empty string) inside each Armour folder.
--   2. Finds the AmmoArea > Lakester NPC in Stage1
--   3. Calls CollisionManager.NonCollidable on each, which sets their
--      CollisionGroup to "Players" (registered at module load time)
--
-- WHY NON-COLLIDABLE: Without this, the Lakester NPC and armour stands would
-- physically block the player. Non-collidable lets the player walk through
-- while touch events still work for the pickup/interaction logic.
--


function Tycoon:SetupCollision()
	local Armour1 = self.Stages.Stage1.Armour1:FindFirstChild("Character")
	local Armour2  = self.Stages.Stage1.Armour2:FindFirstChild("Character")


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
-- ================================================================================
-- Sets up the ProximityPrompt on the Lakester (ammo area NPC) that allows the
-- tycoon owner to reload their weapons. When triggered, it delegates to
-- ReloadConfiguation.onPromptTriggered which handles ammo refilling logic.
--
-- SECURITY (two-layer validation):
--   Both failures are logged via Diagnostics.reject for monitoring exploit attempts.
--
-- GUARD: self.ReloadConfigurationConnected prevents double-setup. This function
-- is called from Init(), but could theoretically be called again if Init runs twice.
-- The guard ensures the prompt connection is only created once.
--
-- MODEL STRUCTURE:
--   Stages.Stage1.AmmoArea.Lakester.Requester.ProximityPrompt
--   intentional fail-fast behavior. If your tycoon model doesn't have an AmmoArea,
--   the FindFirstChild checks will silently skip (no error).
--
-- NOTE: ReloadConfiguation has a typo ("Configuation" instead of "Configuration").
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
-- ================================================================================
-- Completely resets the tycoon to its unclaimed state. Called when the owner
-- leaves the game or when a rebirth occurs. This is the most destructive function
--
-- CLEANUP SEQUENCE (order matters!):
--   1.  Save construction data to the previous owner's profile (PersistenceSystem)
--   4.  Delete all button ECS entities and restore buttons from ButtonTemplate
--   5.  Stop all dropper production loops
--   6.  Restore moved items (BuildService repositioning)
--   7.  Destroy all purchased items in PurchasedItems
--   8.  Destroy all dropper visual effects
--   9.  Release tycoon from BuildService tracking
--  10.  Clear upgrader tracking tables (x2, x3, AppliedUpgraders)
--  11.  Reset construction tracking data
--  12.  Reset gate lever prompt text to "Open Gate" (Stage4.Fences.Leaver)
--  13.  Reset nuke button stand color to green (ready to fire)
--  14.  Reset PlayerRuntimeState flags (Multiplier, Power, ArmourEquipped, etc.)
--  15.  Clear the owner reference and remove the ECS Owner component
--  16.  Disconnect CharacterAdded respawn connection
--
--   The live Buttons folder is DESTROYED and replaced with a fresh clone of
--   ButtonTemplate (saved at Tycoon.new time). This is the ONLY way to reliably
--   modified (some destroyed by Rebirth type, some have changed Transparency,
--   some have their BillboardGui disabled, etc.). Cloning from the template
--   guarantees a clean slate. After cloning, _SetupButtons() is called again
--   to re-create ECS entities and touch events.
--
-- PLAYER RUNTIME STATE RESET (step 14):
--   These runtime flags are read by other systems (client UI, production multipliers,
--   combat, rebirth). If they're not cleared, the player would retain tycoon
--   benefits after leaving. The full list:
--
-- IMPORTANT: This function does NOT destroy the Tycoon object itself. The Tycoon
-- instance persists and can be re-claimed by a new player. Only the runtime state
-- is reset.

function Tycoon:Cleanup()
	local previousOwner = self.Owner
	if previousOwner then
		self:_SaveConstruction(previousOwner)
	end

	local door = self.MainItems.OwnerDoor.Door
	local titleLabel = self.MainItems.OwnerDoor.Title.SurfaceGui.TextLabel
	titleLabel.Text = "Unclaimed Tycoon"
	door.Transparency = 0.25

	self.ATM.Display.SurfaceGui.Money.Text = "0"
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
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.ActionText = "Open Gate"
				end
			end
		end
	end

	local buttonStand = self.Components and self.Components:FindFirstChild("ButtonStand")
	if buttonStand and buttonStand:FindFirstChild("Button") then
		buttonStand.Button.BrickColor = BrickColor.new("Bright green")
	end

	if previousOwner then
		PlayerRuntimeState.ResetTycoonState(previousOwner)
	end


	self.Owner = nil
	ECS.remove(self.Entity, "Owner")


	local characterAddedConn = self.CharacterAddedConn
	self.CharacterAddedConn = nil
	if characterAddedConn then
		characterAddedConn:Disconnect()
	end

	warn(`Cleanup complete: {self.Model.Name}`)
end



-- ================================================================================
-- ================================================================================
-- Sets up the automatic sliding door in the Scientific Lab (Stage2).
-- The door opens when the owner touches either Magnitude zone, then auto-closes
-- after 4 seconds. If the owner is still in the door zone when it tries to close,
-- it reopens and waits again (smart anti-squish logic).
--
-- DOOR MODEL STRUCTURE:
--   Stages.Stage2.ScientificLab.LabDoor/
--
-- DOOR BEHAVIOR FLOW:
--   1. Owner touches Magnitude or Magnitude2
--   2. Door slides open (CFrame offset +13.5 on X, 2s Sine easing)
--
-- SMART ANTI-SQUISH: The isOwnerInDoorZone function uses GetPartBoundsInBox
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
		local closeTarget = Door.PrimaryPart.CFrame * CFrame.new(-13.5, 0, 0)
		TweenManager.Model(Door, closeTarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
		_IsOpen = false
	end

	local function handleDoorTrigger()
		if Debounce then return end
		if Door.BaseDoor.Transparency == 1 then return end
		if not self.Owner then return end

		Debounce = true


		local openTarget = Door.PrimaryPart.CFrame * CFrame.new(13.5, 0, 0)
		TweenManager.Model(Door, openTarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
		_IsOpen = true

		scheduleDoor(4, function()
			closeDoor()
		end)

		scheduleDoor(6, function()
			local owner = self.Owner
			if owner and isOwnerInDoorZone(owner) then
				local reopenTarget = Door.PrimaryPart.CFrame * CFrame.new(13.5, 0, 0)
				TweenManager.Model(Door, reopenTarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
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
		handleDoorTrigger()
	end

	Magnitude.Touched:Connect(onTouched)
	Magnitude2.Touched:Connect(onTouched)
end
-- ================================================================================
-- ================================================================================
-- Sets up the ProximityPrompt on the ButtonStand that allows the tycoon owner
-- to launch a nuclear rocket at another tycoon. This is the endgame weapon.
--
-- MODEL STRUCTURE:
--   Components.ButtonStand.Button.Activate (ProximityPrompt)
--
-- LAUNCH SEQUENCE:
--   1. Validate ownership (only the tycoon owner can launch)
--   2. Validate prompt reachability (anti-exploit distance check)
--   3. Check debounce (nuke has a 1200-second / 20-minute cooldown)
--   4. Create a RocketSystem instance and initialize it
--   8. Change ButtonStand color to red (visual cooldown indicator)
--   9. Schedule a 1200-second cooldown via ECS ScheduledTask
--  10. After cooldown: reset debounce, change button back to green
--
-- COOLDOWN: 1200 seconds = 20 minutes. tracked via ECS ScheduledTask entity
-- named "{TycoonName}:NukeCooldown". The scheduled task runner processes this.
--
-- SECURITY: Two-layer validation (ownership + distance), same as all prompts.
-- Diagnostics.reject logs exploit attempts for monitoring.
--
-- ROCKET TARGETING: RocketSystem receives the full Tycoon.Registry, allowing
-- it to find and target other tycoons. The targeting logic is in RocketSystem,

function Tycoon:_SetupProximityPrompts()
	local Debounce = false

	local ButtonStand  = self.Components.ButtonStand
	local activatePrompt = ButtonStand.Button:FindFirstChild("Activate")
	Diagnostics.invariant(activatePrompt ~= nil and activatePrompt:IsA("ProximityPrompt"), "Tycoon.Nuke", `Activate prompt is missing in {self.Model:GetFullName()}`)
	local ActivateNuke = activatePrompt :: ProximityPrompt

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
-- ================================================================================
-- Sets up touch events on all laser parts in Stage4.Lasers.
--
-- HOW IT WORKS:
--   1. Iterate all children of Stages.Stage4.Lasers
--   2. On touch: if the laser is invisible (Transparency != 0), skip (laser is off)
--   3. If the touching player is the tycoon owner, skip (owner is immune)
--   4. Otherwise, deal 100 damage to the touching player's Humanoid
--
-- DAMAGE: TakeDamage(100) is used instead of setting Health = 0. This respects
-- force fields and other damage-blocking mechanics. 100 damage kills most players
-- instantly (default MaxHealth is 100), but players with armour bonuses
-- (MaxHealth > 100) will survive with reduced health.
--
-- VISIBILITY CHECK: laser.Transparency != 0 means the laser is "off" (invisible).
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
				local hum = Character:FindFirstChildOfClass("Humanoid")

				if hum then
					hum:TakeDamage(100)
				end
			end

		end)
	end
end


-- ================================================================================
-- Tycoon:_SetupGate - Disabled Gate Lever
-- ================================================================================
-- This old gate system is intentionally not called from Init. If it returns, keep
-- translation tweened through TweenService and use constraints such as AlignOrientation
-- for lever rotation instead of a manual per-frame Lerp loop.

-- ================================================================================
-- ================================================================================
-- Sets up touch events on the two armour pickup areas in Stage1.
-- When the tycoon owner touches an armour pickup, a vest model is welded
-- to their character and their MaxHealth is increased.
--
-- TWO ARMOUR TYPES:
--   Armour1 (ArmourVest1): +50 MaxHealth, +50 Health on equip
--   Armour2 (ArmourVest2): +120 MaxHealth, +120 Health on equip
--
-- EQUIP LOGIC:
--   1. Validate: must be owner, armour must be visible (Transparency == 0),
--      and player must NOT already have armour equipped
--   2. Increase MaxHealth and Health by the armour bonus
--   3. Set the PlayerRuntimeState armour flag (prevents double-equipping)
--   4. Clone the vest model from Assets and parent it to the character
--   6. Weld the vest to the torso using WeldConstraint
--
-- WELD CONSTRAINT: Uses WeldConstraint (not Weld) because it doesn't require
-- Part0 = torso (R6: "Torso", R15: "UpperTorso"), Part1 = vest's Primary part.
--
-- IMPORTANT DESIGN NOTES:
--   - Only ONE armour vest can be equipped at a time (PlayerRuntimeState armour guard)
--     The armour runtime flag is cleared in Cleanup(), but the vest model
--     on the character is not explicitly destroyed.
--   - The health bonus persists until the player dies (MaxHealth resets on respawn)
--   - The vest models are cloned at setup time (not on touch), so they're
--     pre-allocated. This means only ONE vest of each type can be active at a time
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
		if PlayerRuntimeState.HasArmourEquipped(player) then return end

		local char = player.Character
		if not char then return end

		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.MaxHealth += 50
			hum.Health += 50
		end

		PlayerRuntimeState.SetArmourEquipped(player, true)
		local torso = (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")) :: BasePart?
		if torso and ArmourVest1.PrimaryPart then
			ArmourVest1.Parent = char
			local offset = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0)
			ArmourVest1:PivotTo(torso.CFrame * offset)
			local newWeld = Instance.new("WeldConstraint")
			newWeld.Part0 = torso
			newWeld.Part1 = ArmourVest1.PrimaryPart
			newWeld.Parent = ArmourVest1.PrimaryPart
		end

	end)


	armour2.Part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= self.Owner then return end
		if armour2.Part.Transparency ~= 0 then return end
		if PlayerRuntimeState.HasArmourEquipped(player) then return end

		local char = player.Character
		if not char then return end

		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.MaxHealth += 120
			hum.Health += 120
		end

		PlayerRuntimeState.SetArmourEquipped(player, true)


		local torso = (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")) :: BasePart?
		if torso and ArmourVest2.PrimaryPart then
			ArmourVest2.Parent = char
			local offset = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0)
			ArmourVest2:PivotTo(torso.CFrame * offset)
			local newWeld = Instance.new("WeldConstraint")
			newWeld.Part0 = torso
			newWeld.Part1 = ArmourVest2.PrimaryPart
			newWeld.Parent = ArmourVest2.PrimaryPart
		end


	end)
end


-- ================================================================================
-- ================================================================================
-- Sets up ProximityPrompt events on all gun models in GunModels.
-- When the tycoon owner activates a gun's prompt, the corresponding weapon
-- tool is cloned from ServerStorage.Guns and placed in their Backpack.
--
-- GUN MODEL STRUCTURE:
--   GunModels/{GunName}/
--   The gun model name must match a tool in ServerStorage.Guns exactly.
--
-- SECURITY (two-layer validation):
--   Both failures are logged via Diagnostics.reject.
--
-- DUPLICATE PREVENTION: Before giving a gun, checks three locations:
--   - player.Backpack (currently held tools)
--   - player.StarterGear (tools given on respawn)
--   - player.Character (currently equipped tools)
-- If the gun exists in ANY of these, the pickup is silently skipped.
-- This prevents players from getting duplicate weapons.
--
-- GUN TEMPLATE SOURCE: ServerStorage.Guns (NOT ReplicatedStorage).
-- ServerStorage is invisible to clients, preventing exploiters from seeing
-- the gun templates. FindFirstChild is used (not WaitForChild) so a missing
-- gun template logs a Diagnostics.report instead of hanging the server.
--
-- COMMENTED-OUT CHECK: There's a commented-out check for gunModel existence
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
-- ================================================================================
-- Checks if ALL Basic (non-gamepass) buttons in the folder have been purchased.
-- Returns true if the tycoon is "complete" (all Basic buttons gone = purchased),
-- false otherwise. Also sets self.CompletedTycoon flag.
--
-- HOW IT WORKS:
--   Iterates all children of the button folder. For each BasePart:
--     (purchased buttons are destroyed by _ApplyPurchasedButton)
--
-- COMPLETION CRITERIA:
--   A tycoon is "complete" when the only remaining buttons are:
--   - Rebirth type (already destroyed, so they won't appear)
--   - Gamepass-gated buttons (optional, don't block completion)
--   Any Basic button still existing = not complete.
--
-- OPERATOR PRECEDENCE WARNING:
--   The condition `not buttonType or buttonType.Value == "Basic" and not button:FindFirstChild("Gamepass")`
--   relies on Lua's operator precedence: `and` binds tighter than `or`.
--   This evaluates as: `not buttonType or (buttonType.Value == "Basic" and not Gamepass)`
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
-- ================================================================================
-- Updates the owner runtime rebirth flag based on completion status.
-- Called after every button purchase and on tycoon claim.
--
-- HOW IT WORKS:
--   2. Call CheckCompletion(self.Buttons) to determine if all Basic buttons are purchased
--   3. Set the PlayerRuntimeState CanRebirth flag to the result
--
-- The CanRebirth runtime flag is read by the client UI to show/hide the rebirth
-- button. It's also read by the rebirth system to validate rebirth requests.
--
-- The actual rebirth logic is handled by a separate system that reads this runtime flag.
--
-- CALLED FROM: _ClaimTycoon (on claim), _SetupButton (when Rebirth buttons are destroyed),
--   and implicitly after any purchase via CheckCompletion.

function Tycoon:_UpdateRebirthAvailability()
	local owner = self.Owner
	if not owner then
		return
	end

	PlayerRuntimeState.SetCanRebirth(owner, self:CheckCompletion(self.Buttons))
end



function Tycoon:SetupTeleportation()
	
	
for _, TeleportModel : Model in self.Stages:QueryDescendants("#Teleporter") do
	--Teleporter is the model
		const TeleportPart : BasePart = TeleportModel:FindFirstChild("Teleport")
	if not TeleportPart then
		warn(`Could not find the Teleport Part for the TeleportationModel: {TeleportModel:GetFullName()}`)
		return
	end
		const TeleportPrompt : ProximityPrompt = TeleportPart:FindFirstChild("TeleportPrompt")
		
		if not TeleportPrompt then
			print(`Could not find the Teleport ProximityPrompt for {TeleportPrompt:GetFullName()}`)
			return
		end
	TeleportPrompt.Triggered:Connect(function(player)
		if self.Owner == player then
				local charPivot = player.Character:GetPivot()

				-- Yaw only: strips out any pitch/roll, keeps the player's facing direction
				local yaw = select(2, charPivot:ToEulerAnglesYXZ())

				-- Place on the ground: subtract half the cylinder's height from its center
				local groundPos = TeleportPart.Position - Vector3.new(0, TeleportPart.Size.Y / 2, 0)

				player.Character:PivotTo(CFrame.new(groundPos) * CFrame.Angles(0, yaw, 0))
				ClientSignals.Send(player, "Teleporting")
		end
	end)

end

end



return Tycoon
