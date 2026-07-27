--!strict

--[[
	Main.luau

	Client-side ACS orchestration script. This file still owns the current equip
	lifecycle, render loop, weapon input, ray casting, and server event calls.
	The surrounding modules now handle smaller responsibilities, but this remains
	the integration layer that keeps old ACS weapons working while the framework is
	being refactored.

	Current architecture:
		Core/    runtime helpers, feature flags, input binding, tool classification
		Combat/  attachments, recoil, hit-region mapping
		Actions/ firing/reload/jam/stance/fall-damage rules
		UI/      SE_GUI adapter and React-readable Player attributes
		WeaponAnimation/ procedural pose layers and ACS animation runner

	Important rule for future edits:
		Do not move networking/damage behavior casually. Server events here are
		part of the ACS contract and should be wrapped first, then replaced.
]]

local Main = {}

function Main.start(hostScript)

local RS 			= game:GetService("ReplicatedStorage")
local RuntimeSettings = require(RS.Modules.SettingsManager.RuntimeSettings)
local ClientRuntimeState = require(RS.Modules.ClientRuntimeState)
local User 			= game:GetService("UserInputService")
local CAS 			= game:GetService("ContextActionService")
local Run 			= game:GetService("RunService")
local TS 			= game:GetService('TweenService')
local PlayersService= game:GetService("Players")

local function destroyLater(instance, lifetime)
	-- Debris is intentionally avoided in this codebase. task.delay gives explicit
	-- ownership and avoids slower service cleanup.
	task.delay(lifetime, function()
		if instance and instance.Parent then
			instance:Destroy()
		end
	end)
end

local Engine 		= RS:WaitForChild("ACS_Engine")
local Evt 			= Engine:WaitForChild("Events")
local Mods 			= Engine:WaitForChild("Modules")
local HUDs 			= Engine:WaitForChild("HUD")
local ArmModel 		= Engine:WaitForChild("ArmModel")
local GunModels 	= Engine:WaitForChild("GunModels")
local AttModels 	= Engine:WaitForChild("AttModels")
local AttModules  	= Engine:WaitForChild("AttModules")
local Rules			= Engine:WaitForChild("GameRules")
local PastaFx		= Engine:WaitForChild("FX")

local gameRules		= require(Rules:WaitForChild("Config"))
local SpringMod 	= require(Mods:WaitForChild("Spring"))
local HitMod 		= require(Mods:WaitForChild("Hitmarker"))
local Thread 		= require(Mods:WaitForChild("Thread"))
local Ultil			= require(Mods:WaitForChild("Utilities"))
local CoreModules = script.Parent:WaitForChild("Core")
local CombatModules = script.Parent:WaitForChild("Combat")
local UIModules = script.Parent:WaitForChild("UI")
local WeaponAnimationModules = script.Parent:WaitForChild("WeaponAnimation")
local ActionModules = script.Parent:WaitForChild("Actions")

-- Core framework helpers own input, runtime services, tool classification, and feature gates.
local Runtime = require(CoreModules:WaitForChild("Runtime"))
local FeatureFlags = require(CoreModules:WaitForChild("FeatureFlags"))
local InputBindings = require(CoreModules:WaitForChild("InputBindings"))
local WeaponToolClassifier = require(CoreModules:WaitForChild("WeaponToolClassifier"))

-- Combat modules keep weapon math and effects away from the equip/render orchestration.
local AttachmentModifiers = require(CombatModules:WaitForChild("AttachmentModifiers"))
local AttachmentController = require(CombatModules:WaitForChild("AttachmentController"))
local HitResolver = require(CombatModules:WaitForChild("HitResolver"))
local RecoilController = require(CombatModules:WaitForChild("RecoilController"))

-- UI remains SE_GUI adapter plus React-readable weapon state while the full HUD redesign is paused.
local WeaponHudAdapter = require(UIModules:WaitForChild("WeaponHudAdapter"))
local StatusEffectsGui = require(UIModules:WaitForChild("StatusEffectsGui"))
local WeaponUIState = require(UIModules:WaitForChild("WeaponUIState"))

local AnimationRunner = require(WeaponAnimationModules:WaitForChild("AnimationRunner"))
local FireEffectsController = require(ActionModules:WaitForChild("FireEffectsController"))
local FallDamageController = require(ActionModules:WaitForChild("FallDamageController"))
local FiremodeController = require(ActionModules:WaitForChild("FiremodeController"))
local JamController = require(ActionModules:WaitForChild("JamController"))
local ReloadController = require(ActionModules:WaitForChild("ReloadController"))
local ShootingController = require(ActionModules:WaitForChild("ShootingController"))
local StanceController = require(ActionModules:WaitForChild("StanceController"))
local WeaponAnimator = require(WeaponAnimationModules:WaitForChild("WeaponAnimator"))
local ECS = require(RS.ECS)
local ProjectileVisuals = require(RS.Modules:WaitForChild("ProjectileVisuals"))

local function schedule(delay: number, callback: () -> (), name: string?)
	-- ECS-backed replacement for loose task.wait/task.delay chains. Scheduled
	-- entities make delayed ACS work easier to inspect later.
	ECS.createEntity({
		Name = name or "ACSClientScheduledTask",
		ScheduledTask = {
			delay = delay,
			elapsed = 0,
			callback = callback,
		},
	})
end

local plr 			= PlayersService.LocalPlayer
local char 			= hostScript:FindFirstAncestorOfClass("Model")
if not char then
	error("[ACS] Character model ancestor was not found")
end

local mouse 		= plr:GetMouse()
local cam 			= Runtime.getCurrentCamera()
local ACS_Client 	= char:FindFirstChild("ACS_Client")
if not ACS_Client then
	error("[ACS] ACS_Client was not found under character")
end

local Ammo
local StoredAmmo

-- Runtime weapon state. These values are reset on equip/unequip and are still
-- shared by existing callbacks, render-step code, and the smaller controller modules.
local WeaponInHand, WeaponTool, WeaponData, AnimData
local ProceduralWeaponAnimator
local ViewModel, AnimPart, LArm, RArm, LArmWeld, RArmWeld, GunWeld
local generateBullet = 1
local BSpread
local RecoilPower
local LastSpreadUpdate = time()
local SE_GUI
local SKP_01 = Evt.AcessId:InvokeServer(plr.UserId)

-- Input/combat flags. A lot of old ACS behavior depends on these exact booleans,
-- so the refactor currently passes them into controllers instead of replacing
-- them with a new state machine all at once.
local charspeed 	= 0
local running 		= false
local runKeyDown 	= false
local aimming 		= false
local shooting 		= false
local reloading 	= false
local mouse1down 	= false
local AnimDebounce 	= false
local CancelReload 	= false
local SafeMode		= false
local JumpDelay 	= false
local NVG 			= false
local GunStance 	= 0
local AimPartMode 	= 1

local CurAimpart 	= nil

local Suppressor 	= false
local FlashHider 	= false

local UnderBarrelAtt= nil

local LaserActive	= false
local IRmode		= false
local IREnable		= false
local Pointer 		= nil


local BipodAtt 		= false
local CanBipod 		= false
local BipodActive 	= false

local GRDebounce 	= false
local CheckingMag	= false

local ToolEquip 	= false
local Sens 			= 50
local Power 		= 150

local BipodCF 		= CFrame.new()
local NearZ 		= CFrame.new(0,0,-.5)

local ModTable = AttachmentModifiers.createDefault()

-- Viewmodel pose state. The procedural animator and ACS CFrame math both
-- feed these values before the render loop applies them to the camera-attached rig.
local maincf 		= CFrame.new() --weapon offset of camera
local guncf  		= CFrame.new() --weapon offset of camera
local gunbobcf		= CFrame.new()
local recoilcf 		= CFrame.new()
local aimcf 		= CFrame.new()
local AimTween 		= TweenInfo.new(
	0.2,
	Enum.EasingStyle.Linear,
	Enum.EasingDirection.InOut,
	0,
	false,
	0
)

local LocalEffectsFolder = Runtime.getEffectsFolder(char)
local Ignore_Model = {cam, char, LocalEffectsFolder}

local ModStorageFolder 	= plr.PlayerGui:FindFirstChild('ModStorage') or Instance.new('Folder')
ModStorageFolder.Parent = plr.PlayerGui
ModStorageFolder.Name 	= 'ModStorage'

-- Keep helper functions on one local table. This avoids global function writes
-- without adding dozens of locals to an already large ACS orchestration scope.
local ACSActions = {}

function ACSActions.RAND(Min, Max, Accuracy)
	return Runtime.randomRange(Min, Max, Accuracy)
end

local StatusEffects = StatusEffectsGui.create(plr.PlayerGui, HUDs)
SE_GUI = StatusEffects.gui

local lastCrosshairDebugState = ""
WeaponUIState.clear(plr)

local ManualCrosshairGui: ScreenGui? = nil

local function destroyManualCrosshair()
	if ManualCrosshairGui then
		ManualCrosshairGui:Destroy()
		ManualCrosshairGui = nil
	end
end

local function ensureManualCrosshair()
	-- React still owns the polished weapon HUD, but ACS keeps this direct fallback
	-- so aiming feedback never disappears if the UI tree starts late or reloads.
	if ManualCrosshairGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ACSManualCrosshair"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90
	gui.Parent = plr:WaitForChild("PlayerGui")

	local image = Instance.new("ImageLabel")
	image.Name = "Crosshair"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromOffset(34, 34)
	image.BackgroundTransparency = 1
	image.Image = "rbxassetid://108394139789219"
	image.ImageColor3 = Color3.fromRGB(255, 255, 255)
	image.ImageTransparency = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = gui

	local fallback = Instance.new("Frame")
	fallback.Name = "FallbackLines"
	fallback.AnchorPoint = Vector2.new(0.5, 0.5)
	fallback.Position = UDim2.fromScale(0.5, 0.5)
	fallback.Size = UDim2.fromOffset(18, 18)
	fallback.BackgroundTransparency = 1
	fallback.Visible = false
	fallback.Parent = gui

	local function line(name: string, position: UDim2, size: UDim2)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = position
		frame.Size = size
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		frame.Parent = fallback
	end

	line("Top", UDim2.fromScale(0.5, 0.1), UDim2.fromOffset(1, 8))
	line("Bottom", UDim2.fromScale(0.5, 0.9), UDim2.fromOffset(1, 8))
	line("Left", UDim2.fromScale(0.1, 0.5), UDim2.fromOffset(8, 1))
	line("Right", UDim2.fromScale(0.9, 0.5), UDim2.fromOffset(8, 1))

	task.delay(1.5, function()
		if image.Parent and not image.IsLoaded then
			fallback.Visible = true
			image.Visible = false
		end
	end)

	ManualCrosshairGui = gui
end

-- Springs here affect camera/viewmodel feel directly. RecoilController and
-- procedural animation layers push into these instead of creating their own camera.
local RecoilSpring = SpringMod.new(Vector3.new())
RecoilSpring.d = .1
RecoilSpring.s = 20

local cameraspring = SpringMod.new(Vector3.new())
cameraspring.d	= .5
cameraspring.s	= 20

local SwaySpring = SpringMod.new(Vector3.new())
SwaySpring.d = .25
SwaySpring.s = 20

local Stance = Evt.Stance
local Stances = 0
local Virar = 0
local CameraX = 0
local CameraY = 0

local Sentado 		= false
local Swimming		= false
--local Proned		= false
local Steady 		= false
local ChangeStance 	= true

--// Char Parts
local Humanoid 	= char:WaitForChild('Humanoid')
local Torso 	= char:WaitForChild('Torso')
local HumanoidRootPart 	= char:WaitForChild('HumanoidRootPart')

local FallDamage = FallDamageController.new({
	Player = plr,
	UserIdToken = SKP_01,
	Humanoid = Humanoid,
	HumanoidRootPart = HumanoidRootPart,
	GameRules = gameRules,
	RunService = Run,
	Events = Evt,
	FxFolder = PastaFx,
	CameraSpring = cameraspring,
	SwaySpring = SwaySpring,
	DestroyLater = destroyLater,
})
local Neck 				= Torso:WaitForChild('Neck')

local CFNew, CFAng = CFrame.new, CFrame.Angles
local Asin = math.asin
local AIM_RIG_PITCH_SCALE = 0.72

User.MouseIconEnabled 	= true
plr.CameraMode 			= Enum.CameraMode.Classic

cam.CameraType = Enum.CameraType.Custom
cam.CameraSubject = Humanoid

local viewModelEnabledStates = {}
local viewModelTransparencyStates = {}

local function isThirdPersonCamera()
	-- Third person is the new default. RuntimeSettings owns the camera preference.
	return RuntimeSettings.GetBoolean("Third Person", true)
end

local function getWeaponName()
	-- Several old weapons do not declare weapon categories, so name fallback keeps
	-- crosshair behavior reasonable until configs are cleaned.
	return string.lower((WeaponTool and WeaponTool.Name) or "")
end

local function isShotgunWeapon()
	-- Prefer explicit config, then fallback to common shotgun names.
	if not WeaponData then
		return false
	end

	if WeaponData.WeaponType == "Shotgun" or WeaponData.Shotgun == true then
		return true
	end

	local weaponName = getWeaponName()
	return string.find(weaponName, "shotgun", 1, true) ~= nil
		or string.find(weaponName, "spas", 1, true) ~= nil
		or string.find(weaponName, "mossberg", 1, true) ~= nil
end

local function isSniperWeapon()
	-- Snipers should keep ADS/scope behavior instead of the generic image
	-- crosshair. Low Zoom values are treated as sniper-like.
	if not WeaponData then
		return false
	end

	local weaponName = getWeaponName()
	if WeaponData.Sniper == true or WeaponData.WeaponType == "Sniper" then
		return true
	end

	if string.find(weaponName, "sniper", 1, true)
		or string.find(weaponName, "barrett", 1, true)
		or string.find(weaponName, "awm", 1, true)
		or string.find(weaponName, "m82", 1, true)
		or string.find(weaponName, "kar98", 1, true) then
		return true
	end

	return typeof(WeaponData.Zoom) == "number" and WeaponData.Zoom <= 25 and not isShotgunWeapon()
end

local function shouldUseThirdPersonImageCrosshair()
	-- Crosshair is shown for equipped guns unless a sniper is actively aiming.
	return ToolEquip
		and WeaponData
		and WeaponData.Type == "Gun"
		and not (aimming and isSniperWeapon())
end

local function updateThirdPersonCrosshair()
	-- Publish only simple attributes. React owns the actual ImageLabel rendering.
	local active = shouldUseThirdPersonImageCrosshair()
	local state = if active then `active:{if isShotgunWeapon() then "shotgun" else "rifle"}:{if isThirdPersonCamera() then "third" else "first"}` else "hidden"

	if lastCrosshairDebugState ~= state then
		lastCrosshairDebugState = state
	end

	local shotgun = isShotgunWeapon()
	WeaponUIState.publishCrosshair(plr, {
		visible = active == true,
		kind = if active and shotgun then "shotgun" elseif active then "rifle" else "none",
		mode = if isThirdPersonCamera() then "third" else "first",
	})

	if active then
		ensureManualCrosshair()
	else
		destroyManualCrosshair()
	end
end

local function getThirdPersonAimDirection(origin)
	-- Third-person bullets aim from the center of the screen, not the muzzle's
	-- raw forward vector, so shots line up with the crosshair.
	local viewport = cam.ViewportSize
	local ray = cam:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)
	local target = ray.Origin + ray.Direction * 10000
	local direction = target - origin

	if direction.Magnitude <= 0.001 then
		return ray.Direction
	end

	return direction.Unit
end

local function applyWeaponCameraMode()
	-- Camera mode is controlled by settings, but weapon equip must re-assert it so
	-- Roblox/default camera changes do not fight the combat camera.
	if isThirdPersonCamera() then
		plr.CameraMode = Enum.CameraMode.Classic
	else
		plr.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

local function setViewModelVisible(visible)
	-- The local arms rig still exists while in third person; it is hidden locally
	-- so the player sees their character instead of duplicate first-person arms.
	if not ViewModel then
		return
	end

	for _, descendant in pairs(ViewModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if visible then 0 else 1
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") then
			if viewModelEnabledStates[descendant] == nil then
				viewModelEnabledStates[descendant] = descendant.Enabled
			end
			descendant.Enabled = if visible then viewModelEnabledStates[descendant] else false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			if viewModelTransparencyStates[descendant] == nil then
				viewModelTransparencyStates[descendant] = descendant.Transparency
			end
			descendant.Transparency = if visible then viewModelTransparencyStates[descendant] else 1
		end
	end
end

RuntimeSettings.Observe("Third Person", function()
	-- Settings can flip camera mode while a weapon is already equipped.
	if ToolEquip then
		applyWeaponCameraMode()
	end
end)

local function tweenStanceCameraOffset()
	-- CharacterMotion can own camera offset. If it does, ACS stance offset backs
	-- off to avoid two systems fighting over Humanoid.CameraOffset.
	if RuntimeSettings.GetBoolean("CameraControllerOwnsOffset", false) then
		return
	end

	TS:Create(char.Humanoid, TweenInfo.new(.3), {CameraOffset = Vector3.new(CameraX,CameraY,char.Humanoid.CameraOffset.Z)} ):Play()
end

 local function getStanceContext()
	-- StanceController receives a compact context instead of reaching back into
	-- every local in Main.
	return {
		humanoid = char.Humanoid,
		characterModel = hostScript.Parent,
		gameRules = gameRules,
	}
end

local function enterThirdPersonCombatFocus()
	-- Fortnite/GTA-style behavior: firing pulls the character into combat focus
	-- without forcing first-person ADS.
	if not isThirdPersonCamera() then
		return
	end
	if aimming or not WeaponData or not WeaponData.canAim or GunStance <= -2 or runKeyDown or CheckingMag then
		return
	end

	aimming = true
	ACSActions.ADS(aimming)
end

function ACSActions.handleAction(actionName, inputState, _inputObject)

	if actionName == "Fire" and inputState == Enum.UserInputState.Begin and AnimDebounce then
		enterThirdPersonCombatFocus()
		ACSActions.Shoot()

	elseif actionName == "Fire" and inputState == Enum.UserInputState.End then
		mouse1down = false
	end

	if actionName == "Reload" and inputState == Enum.UserInputState.Begin and AnimDebounce and not CheckingMag and not reloading then
		if WeaponData.Jammed then
			ACSActions.Jammed()
		else
			ACSActions.Reload()
		end
	end

	if actionName == "Reload" and inputState == Enum.UserInputState.Begin and reloading and WeaponData.ShellInsert then
		CancelReload = true
	end

	if actionName == "CycleFiremode" and inputState == Enum.UserInputState.Begin and WeaponData and WeaponData.FireModes.ChangeFiremode then
		ACSActions.Firemode()
	end

	if actionName == "ADS" and inputState == Enum.UserInputState.Begin and AnimDebounce then
		if WeaponData and WeaponData.canAim and GunStance > -2 and not runKeyDown and not CheckingMag then
			aimming = not aimming
			ACSActions.ADS(aimming)
		end
	end

	if actionName == "Stand" and inputState == Enum.UserInputState.Begin and ChangeStance and not Swimming and not Sentado and not runKeyDown and not ACS_Client:GetAttribute("Collapsed") then
		if Stances == 2 then
			--Proned = false
			Stances = 1
			CameraY = -1
			ACSActions.Crouch()


		elseif Stances == 1 then		
			Stances = 0
			CameraY = 0
			ACSActions.Stand()
		end	
	end

	if actionName == "Crouch" and inputState == Enum.UserInputState.Begin and ChangeStance and not Swimming and not Sentado and not runKeyDown and not ACS_Client:GetAttribute("Collapsed") then
		if Stances == 0 then
			Stances = 1
			CameraY = -1
			ACSActions.Crouch()
		elseif Stances == 1 then	
			Stances = 2
			CameraX = 0
			CameraY = -3.25
			Virar = 0
			--Lean()
			--Prone()
			--Proned = true
		end
	end

	if actionName == "ToggleWalk" and inputState == Enum.UserInputState.Begin and ChangeStance and not runKeyDown then
		Steady = not Steady

		

		if Stances == 0 then
			ACSActions.Stand()
		end
	end

	--if actionName == "LeanLeft" and inputState == Enum.UserInputState.Begin and Stances ~= 2 and ChangeStance and not Swimming and not runKeyDown  and not ACS_Client:GetAttribute("Collapsed") then
	--	if Virar == 0 or Virar == 1 then
	--		Virar = -1
	--		CameraX = -1.25
	--	else
	--		Virar = 0
	--		CameraX = 0
	--	end
	--	--Lean()
	--end

	--if actionName == "LeanRight" and inputState == Enum.UserInputState.Begin and Stances ~= 2 and ChangeStance and not Swimming and not runKeyDown and not ACS_Client:GetAttribute("Collapsed") then
	--	if Virar == 0 or Virar == -1 then
	--		Virar = 1
	--		CameraX = 1.25
	--	else
	--		Virar = 0
	--		CameraX = 0
	--	end
	--	--Lean()
	--end

	if actionName == "Run" and inputState == Enum.UserInputState.Begin and running and not hostScript.Parent:GetAttribute("Injured") then
		mouse1down = false		
		runKeyDown 	= true
		ACSActions.Stand()
		Stances = 0
		Virar = 0
		CameraX = 0
		CameraY = 0
		--Lean()

		char:WaitForChild("Humanoid").WalkSpeed = gameRules.RunWalkSpeed

		if aimming then
			aimming = false
			ACSActions.ADS(aimming)
		end

		if not CheckingMag and not reloading and WeaponData and WeaponData.Type ~= "Grenade" and (GunStance == 0 or GunStance == 2 or GunStance == 3) then
			GunStance = 3
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.SprintAnim()
		end

	elseif actionName == "Run" and inputState == Enum.UserInputState.End and runKeyDown then
		runKeyDown 	= false
		ACSActions.Stand()
		if not CheckingMag and not reloading and WeaponData and WeaponData.Type ~= "Grenade" and (GunStance == 0 or GunStance == 2 or GunStance == 3) then
			GunStance = 0
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.IdleAnim()
		end
	end
end

function ACSActions.resetMods()
	AttachmentController.resetModifiers(ModTable)
end

function ACSActions.loadAttachment(weapon)
	-- AttachmentController performs the actual cloning/welding/modifier math.
	-- Main keeps only the few runtime flags used by HUD, recoil, and utility code.
	local attachments = AttachmentController.load(weapon, WeaponData, ModTable, AttModels, AttModules, Ultil)

	UnderBarrelAtt = attachments.underBarrel
	Suppressor = attachments.suppressor
	FlashHider = attachments.flashHider
	IREnable = IREnable or attachments.infrared
	BipodAtt = attachments.bipod

	if FeatureFlags.WeaponUtilitiesEnabled and BipodAtt then
		CAS:BindAction("ToggleBipod", ACSActions.handleAction, true, Enum.KeyCode.B)
	end
end

function ACSActions.ADS(isAiming)
	-- ADS still uses ACS stance replication, but third-person camera mode
	-- prevents FOV snapping into a full first-person scope unless the weapon needs it.
	if not WeaponData or not WeaponInHand then
		return
	end
	WeaponUIState.setAiming(plr, isAiming)
	if isAiming then

		if SafeMode then
			SafeMode = false
			GunStance = 0
			ACSActions.IdleAnim()
			ACSActions.UpdateGui()
		end

		game:GetService('UserInputService').MouseDeltaSensitivity = (Sens/100)

		WeaponInHand.Handle.AimDown:Play()

		GunStance = 2
		Evt.GunStance:FireServer(GunStance,AnimData)

	else
		game:GetService('UserInputService').MouseDeltaSensitivity = 1
		WeaponInHand.Handle.AimUp:Play()

		GunStance = 0
		Evt.GunStance:FireServer(GunStance,AnimData)
	end
	updateThirdPersonCrosshair()
end

function ACSActions.Firemode()
	-- FiremodeController owns the mode transition; Main handles sound and HUD.
	WeaponInHand.Handle.SafetyClick:Play()
	mouse1down = false
	FiremodeController.cycle(WeaponData)
	ACSActions.UpdateGui()
end

function ACSActions.setup(Tool)
	-- Full weapon equip pipeline:
	-- 1. read tool config/animations
	-- 2. clone weapon and first-person arms
	-- 3. create Motor6D welds for arms/gun
	-- 4. bind weapon controls
	-- 5. load attachments and initialize ammo/recoil/HUD state

	if not char or not Tool or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return; end;

	local ToolCheck 		= Tool
	local GunModelCheck 	= GunModels:FindFirstChild(Tool.Name)

	if not ToolCheck or not GunModelCheck then
		warn("Tool Or Gun Model Doesn't Exist")
		return
	end

	ToolEquip = true
	User.MouseIconEnabled 	= false
	WeaponUIState.setAiming(plr, false)
	applyWeaponCameraMode()

	WeaponTool 		= ToolCheck
	WeaponData 		= require(Tool:FindFirstChild("ACS_Settings"))
	AnimData 		= require(Tool:FindFirstChild("ACS_Animations"))
	SafeMode = false
	GunStance = 0
	Evt.GunStance:FireServer(GunStance, AnimData)
	-- ProceduralWeaponAnimator layers subtle runtime motion over the authored
	-- CFrames coming from ACS_Animations.
	updateThirdPersonCrosshair()
	ProceduralWeaponAnimator = WeaponAnimator.new(AnimData)
	WeaponInHand 	= GunModelCheck:Clone()
	WeaponInHand.PrimaryPart = WeaponInHand:WaitForChild("Handle")

	Evt.Equip:FireServer(Tool,1,WeaponData,AnimData)

	ViewModel = ArmModel:WaitForChild("Arms"):Clone()
	ViewModel.Name = "Viewmodel"
	-- These caches let third-person mode hide the local viewmodel and later
	-- restore original transparencies/enabled states when returning to first person.
	viewModelEnabledStates = {}
	viewModelTransparencyStates = {}

	if char:WaitForChild("Body Colors") then
		local Colors = char:WaitForChild("Body Colors"):Clone()
		Colors.Parent = ViewModel
	end

	if char:FindFirstChild("Shirt") then
		local Shirt = char:FindFirstChild("Shirt"):Clone()
		Shirt.Parent = ViewModel
	end

	AnimPart = Instance.new("Part")
	AnimPart.Parent = ViewModel
	-- AnimPart is the invisible root that follows the camera. Arm/gun welds attach
	-- to it, which is the classic ACS first-person viewmodel pattern.
	AnimPart.Size = Vector3.new(0.1,0.1,0.1)
	AnimPart.Anchored = true
	AnimPart.CanCollide = false
	AnimPart.Transparency = 1

	ViewModel.PrimaryPart = AnimPart

	LArmWeld = Instance.new("Motor6D")
	LArmWeld.Parent = AnimPart
	-- The arm welds are animated by CFrame changes from weapon animation modules
	-- and procedural pose layers, not by Roblox Humanoid animation tracks.
	LArmWeld.Name = "LeftArm"
	LArmWeld.Part0 = AnimPart

	RArmWeld = Instance.new("Motor6D")
	RArmWeld.Parent = AnimPart
	RArmWeld.Name = "RightArm"
	RArmWeld.Part0 = AnimPart

	GunWeld = Instance.new("Motor6D")
	GunWeld.Parent = AnimPart
	GunWeld.Name = "Handle"

	--setup arms to camera

	ViewModel.Parent = cam

	maincf = AnimData.MainCFrame
	guncf = AnimData.GunCFrame
	gunbobcf = CFrame.new()

	updateThirdPersonCrosshair()

	LArm = ViewModel:WaitForChild("Left Arm")
	LArmWeld.Part1 = LArm
	LArmWeld.C0 = CFrame.new()
	LArmWeld.C1 = CFrame.new(1,-1,-5) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)):inverse()

	RArm = ViewModel:WaitForChild("Right Arm")
	RArmWeld.Part1 = RArm
	RArmWeld.C0 = CFrame.new()
	RArmWeld.C1 = CFrame.new(-1,-1,-5) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0)):inverse()
	GunWeld.Part0 = RArm

	LArm.Anchored = false
	RArm.Anchored = false

	--setup weapon to camera
	ModTable.ZoomValue 		= WeaponData.Zoom
	ModTable.Zoom2Value 	= WeaponData.Zoom2
	IREnable 				= WeaponData.InfraRed


	CAS:BindAction("Fire", ACSActions.handleAction, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	-- Weapon-specific actions are bound only while equipped so normal character
	-- controls remain clean when no ACS weapon is active.
	CAS:BindAction("ADS", ACSActions.handleAction, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2) 
	CAS:BindAction("Reload", ACSActions.handleAction, true, Enum.KeyCode.R, Enum.KeyCode.ButtonB)
	CAS:BindAction("CycleFiremode", ACSActions.handleAction, false, Enum.KeyCode.V)
	
	CAS:SetPosition("Reload", UDim2.new(0.8, 0, 0.2, 0))  -- adjust position as needed

	CAS:SetImage("Reload", "rbxassetid://134368074293877")
	CAS:SetImage("Fire", "rbxassetid://99203026125033")
	CAS:SetImage("ADS", "rbxassetid://632007943")
	
	
	
	ACSActions.loadAttachment(WeaponInHand)

	-- Spread/recoil start at the weapon minimums, after attachment multipliers
	-- have had a chance to adjust the modifier table.
	BSpread				= math.min(WeaponData.MinSpread * ModTable.MinSpread, WeaponData.MaxSpread * ModTable.MaxSpread)
	RecoilPower 		= math.min(WeaponData.MinRecoilPower * ModTable.MinRecoilPower, WeaponData.MaxRecoilPower * ModTable.MaxRecoilPower)

	Ammo = WeaponData.AmmoInGun
	StoredAmmo = WeaponData.StoredAmmo
	CurAimpart = WeaponInHand:FindFirstChild("AimPart")


	WeaponHudAdapter.setVisible(SE_GUI, WeaponData.EnableHUD == true)
	ACSActions.UpdateGui()

	for _, key in pairs(WeaponInHand:GetChildren()) do
		if key:IsA('BasePart') and key.Name ~= 'Handle' then

			if key.Name ~= "Bolt" and key.Name ~= 'Lid' and key.Name ~= "Slide" then
				Ultil.Weld(WeaponInHand:WaitForChild("Handle"), key)
			end

			if key.Name == "Bolt" or key.Name == "Slide" then
				Ultil.WeldComplex(WeaponInHand:WaitForChild("Handle"), key, key.Name)
			end;

			if key.Name == "Lid" then
				if WeaponInHand:FindFirstChild('LidHinge') then
					Ultil.Weld(key, WeaponInHand:WaitForChild("LidHinge"))
				else
					Ultil.Weld(key, WeaponInHand:WaitForChild("Handle"))
				end
			end
		end
	end;

	for _, weaponChild in pairs(WeaponInHand:GetChildren()) do
		if weaponChild:IsA('BasePart') then
			weaponChild.Anchored = false
			weaponChild.CanCollide = false
		end
	end;

	if WeaponInHand:FindFirstChild("Nodes") then
		for _, nodePart in pairs(WeaponInHand.Nodes:GetChildren()) do
			if nodePart:IsA('BasePart') then
				Ultil.Weld(WeaponInHand:WaitForChild("Handle"), nodePart)
				nodePart.Anchored = false
				nodePart.CanCollide = false
			end
		end;
	end

	GunWeld.Part1 = WeaponInHand:WaitForChild("Handle")
	GunWeld.C1 = guncf

	--WeaponInHand:SetPrimaryPartCFrame( RArm.CFrame * guncf)

	WeaponInHand.Parent = ViewModel	
	if Ammo <= 0 and WeaponData.Type == "Gun" then
		WeaponInHand.Handle.Slide.C0 = WeaponData.SlideEx:inverse()
	end
	ACSActions.EquipAnim()
	if WeaponData and WeaponData.Type ~= "Grenade" then
		ACSActions.RunCheck()
	end

end

function ACSActions.unset()
	ToolEquip = false
	WeaponUIState.setAiming(plr, false)
	Evt.Equip:FireServer(WeaponTool,2)
	--unsetup weapon data module
	CAS:UnbindAction("Fire")
	CAS:UnbindAction("ADS")
	CAS:UnbindAction("Reload")
	CAS:UnbindAction("CycleFiremode")

	mouse1down = false
	aimming = false

	TS:Create(cam,AimTween,{FieldOfView = 70}):Play()
	WeaponUIState.clear(plr)
	WeaponUIState.publishCrosshair(plr, {
		visible = false,
		kind = "none",
		mode = if isThirdPersonCamera() then "third" else "first",
	})
	destroyManualCrosshair()

	User.MouseIconEnabled = true
	game:GetService('UserInputService').MouseDeltaSensitivity = 1
	cam.CameraType = Enum.CameraType.Custom
	plr.CameraMode = Enum.CameraMode.Classic


	if WeaponInHand then

		WeaponData.AmmoInGun = Ammo
		WeaponData.StoredAmmo = StoredAmmo

		ViewModel:Destroy()
		ViewModel 		= nil
		WeaponInHand	= nil
		WeaponTool		= nil
		LArm 			= nil
		RArm 			= nil
		LArmWeld 		= nil
		RArmWeld 		= nil
		WeaponData 		= nil
		AnimData		= nil
		ProceduralWeaponAnimator = nil
		UnderBarrelAtt 	= nil
		LaserActive		= false
		IRmode			= false
		BipodAtt 		= false
		BipodActive 	= false
		Pointer 		= nil
		BSpread 		= nil
		RecoilPower 	= nil
		Suppressor 		= false
		FlashHider 		= false
		CancelReload 	= false
		reloading 		= false
		SafeMode		= false
		CheckingMag		= false
		GRDebounce 		= false
		GunStance 		= 0
		ACSActions.resetMods()
		generateBullet 	= 1
		AimPartMode 	= 1

		WeaponHudAdapter.setVisible(SE_GUI, false)
		WeaponHudAdapter.hideGrenadeForce(SE_GUI)
		BipodCF = CFrame.new()
		if gameRules.ReplicatedLaser then
			Evt.SVLaser:FireServer(nil,2,nil,false,WeaponTool)
		end
	end
end

local HalfStep = false
function ACSActions.HeadMovement()
	-- Sends first-person/third-person neck rotation to the server at half-rate.
	-- This keeps other players seeing where the character is looking without
	-- firing a remote every single rendered frame.
	if not ClientRuntimeState.HasLoaded(plr) or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return; end;
	if char.Humanoid.RigType == Enum.HumanoidRigType.R15 then return; end;
	if not ACS_Client or ACS_Client:GetAttribute("Collapsed") then return; end;
	local CameraDirection = char.HumanoidRootPart.CFrame:toObjectSpace(cam.CFrame).lookVector
	if Neck then
		HalfStep = not HalfStep
		local neckCFrame = CFNew(0, -.5, 0) * CFAng(0, Asin(CameraDirection.x)/1.15, 0) * CFAng(-Asin(cam.CFrame.LookVector.y)+Asin(char.Torso.CFrame.lookVector.Y), 0, 0) * CFAng(-math.rad(90), 0, math.rad(180))
		TS:Create(Neck, TweenInfo.new(.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {C1 = neckCFrame}):Play()
		local aimingRig = ToolEquip and aimming and WeaponData and WeaponData.Type == "Gun"
		local aimPitch = if aimingRig then math.clamp(Asin(cam.CFrame.LookVector.Y), -1.1, 1.1) else 0
		local animBase = char:FindFirstChild("AnimBase")
		local animBaseW = animBase and animBase:FindFirstChild("AnimBaseW")
		if animBaseW and animBaseW:IsA("Motor6D") then
			TS:Create(animBaseW, TweenInfo.new(.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				C0 = CFAng(aimPitch * AIM_RIG_PITCH_SCALE, 0, 0),
			}):Play()
		end
		if not HalfStep then return; end;
		Evt.HeadRot:FireServer(neckCFrame, aimPitch, aimingRig == true)
	end
end

function ACSActions.renderCam()			
	-- Camera recoil spring is applied last so it affects every camera mode.
	cam.CFrame = cam.CFrame*CFrame.Angles(cameraspring.p.x,cameraspring.p.y,cameraspring.p.z)
end

function ACSActions.Recoil()
	-- Split recoil into two layers: procedural weapon pose recoil and camera
	-- spring recoil. This gives kick without making ADS sway uncontrollable.
	if ProceduralWeaponAnimator then
		ProceduralWeaponAnimator:Fire(RecoilPower)
	end

	recoilcf = RecoilController.apply({
		WeaponData = WeaponData,
		ModTable = ModTable,
		BipodActive = BipodActive,
		Aiming = aimming,
		RecoilPower = RecoilPower,
		CameraSpring = cameraspring,
		RecoilSpring = RecoilSpring,
		RecoilCFrame = recoilcf,
		RandomRange = ACSActions.RAND,
		Schedule = function(duration, callback)
			schedule(duration, callback, "ACS:RecoilRecover")
		end,
	})
end

function ACSActions.CheckForHumanoid(hitPart)
	local result = HitResolver.findHumanoid(hitPart)
	return result.found, result.humanoid
end

function ACSActions.CastRay(Bullet, Origin)
	-- ACS physical projectile tracker. The invisible bullet moves through the
	-- world and each heartbeat raycasts between the previous/current positions.
	-- This preserves ACS whizz/suppression/hit behavior while visual tracers can
	-- be handled by ProjectileVisuals.
	if not Bullet then return; end;

	local Bpos = Bullet.Position
	local Bpos2 = cam.CFrame.Position

	local TotalDistTraveled = 0
	local Debounce = false

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = Ignore_Model
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local connection: RBXScriptConnection?
	local function cleanup()
		-- Disconnect heartbeat as soon as a bullet is destroyed or hits something.
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	connection = Run.Heartbeat:Connect(function()
		if not Bullet or not Bullet.Parent then
			cleanup()
			return
		end

		Bpos = Bullet.Position
		TotalDistTraveled = (Bullet.Position - Origin).Magnitude

		if TotalDistTraveled > 7000 then
			Bullet:Destroy()
			Debounce = true
			cleanup()
			return
		end

		for _, plyr in pairs(game.Players:GetPlayers()) do
			-- Whizz/suppression is proximity-based, not only hit-based. Nearby
			-- players get feedback when a bullet passes close to their head.
			if Debounce or plyr == plr or not plyr.Character or not plyr.Character:FindFirstChild('Head') or (plyr.Character.Head.Position - Bpos).magnitude > 25 then continue; end;
			Evt.Whizz:FireServer(plyr)
			Evt.Suppression:FireServer(plyr,1,nil,nil)
			Debounce = true
		end

		-- Set an origin and directional vector
		local raycastResult = workspace:Raycast(Bpos2, (Bpos - Bpos2) * 1, raycastParams)

		if raycastResult then
			local Hit2 = raycastResult.Instance
			local hitParent = Hit2 and Hit2.Parent

			if Hit2 and hitParent and (hitParent:IsA('Accessory') or hitParent:IsA('Hat')) then
				for _,players in pairs(game.Players:GetPlayers()) do
					if players.Character then
						for _, hats in pairs(players.Character:GetChildren()) do
							if hats:IsA("Accessory") then
								table.insert(Ignore_Model, hats)
							end
						end
					end
				end
				return
			end

			if Hit2 and hitParent and (Hit2.Name == "Ignorable" or Hit2.Name == "Glass" or Hit2.Name == "Ignore" or hitParent.Name == "Top" or hitParent.Name == "Helmet" or hitParent.Name == "Up" or hitParent.Name == "Down" or hitParent.Name == "Face" or hitParent.Name == "Olho" or hitParent.Name == "Headset" or hitParent.Name == "Numero" or hitParent.Name == "Vest" or hitParent.Name == "Chest" or hitParent.Name == "Waist" or hitParent.Name == "Back" or hitParent.Name == "Belt" or hitParent.Name == "Leg1" or hitParent.Name == "Leg2" or hitParent.Name == "Arm1"  or hitParent.Name == "Arm2") then
				-- Armor/accessory shell parts should not stop the bullet ray. Add
				-- them to the ignore list and keep tracing.
				table.insert(Ignore_Model, Hit2)
				raycastParams.FilterDescendantsInstances = Ignore_Model
				return
			end

			if Hit2 and hitParent and (hitParent.Name == "Top" or hitParent.Name == "Helmet" or hitParent.Name == "Up" or hitParent.Name == "Down" or hitParent.Name == "Face" or hitParent.Name == "Olho" or hitParent.Name == "Headset" or hitParent.Name == "Numero" or hitParent.Name == "Vest" or hitParent.Name == "Chest" or hitParent.Name == "Waist" or hitParent.Name == "Back" or hitParent.Name == "Belt" or hitParent.Name == "Leg1" or hitParent.Name == "Leg2" or hitParent.Name == "Arm1"  or hitParent.Name == "Arm2") then
				table.insert(Ignore_Model, hitParent)
				raycastParams.FilterDescendantsInstances = Ignore_Model
				return
			end

			if Hit2 and (Hit2.Transparency >= 1 or Hit2.CanCollide == false) and Hit2.Name ~= 'Head' and Hit2.Name ~= 'Right Arm' and Hit2.Name ~= 'Left Arm' and Hit2.Name ~= 'Right Leg' and Hit2.Name ~= 'Left Leg' and Hit2.Name ~= "UpperTorso" and Hit2.Name ~= "LowerTorso" and Hit2.Name ~= "RightUpperArm" and Hit2.Name ~= "RightLowerArm" and Hit2.Name ~= "RightHand" and Hit2.Name ~= "LeftUpperArm" and Hit2.Name ~= "LeftLowerArm" and Hit2.Name ~= "LeftHand" and Hit2.Name ~= "RightUpperLeg" and Hit2.Name ~= "RightLowerLeg" and Hit2.Name ~= "RightFoot" and Hit2.Name ~= "LeftUpperLeg" and Hit2.Name ~= "LeftLowerLeg" and Hit2.Name ~= "LeftFoot" and Hit2.Name ~= 'Armor' and Hit2.Name ~= 'EShield' then
				table.insert(Ignore_Model, Hit2)
				raycastParams.FilterDescendantsInstances = Ignore_Model
				return
			end

			do

				Bullet:Destroy()
				Debounce = true
				cleanup()

				local FoundHuman,VitimaHuman = ACSActions.CheckForHumanoid(raycastResult.Instance)
				-- Local hit effects play immediately, then the server replicates the
				-- same impact for other clients.
				HitMod.HitEffect(Ignore_Model, raycastResult.Position, raycastResult.Instance , raycastResult.Normal, raycastResult.Material, WeaponData)
				Evt.HitEffect:FireServer(raycastResult.Position, raycastResult.Instance , raycastResult.Normal, raycastResult.Material, WeaponData)

				local HitPart = raycastResult.Instance
				TotalDistTraveled = (raycastResult.Position - Origin).Magnitude

				if FoundHuman == true and VitimaHuman.Health > 0 and WeaponData then
					local SKP_02 = SKP_01.."-"..plr.UserId

					if HitPart.Name == "Head" or HitPart.Parent.Name == "Top" or HitPart.Parent.Name == "Headset" or HitPart.Parent.Name == "Olho" or HitPart.Parent.Name == "Face" or HitPart.Parent.Name == "Numero" then
						Evt.Damage:InvokeServer(WeaponTool, VitimaHuman, TotalDistTraveled, 1, WeaponData, ModTable, nil, nil, SKP_02)
					elseif HitPart.Name == "Torso" or HitPart.Name == "UpperTorso" or HitPart.Name == "LowerTorso" or HitPart.Parent.Name == "Chest" or HitPart.Parent.Name == "Waist" or HitPart.Name == "Right Arm" or HitPart.Name == "Left Arm" or HitPart.Name == "RightUpperArm" or HitPart.Name == "RightLowerArm" or HitPart.Name == "RightHand" or HitPart.Name == "LeftUpperArm" or HitPart.Name == "LeftLowerArm" or HitPart.Name == "LeftHand" then				
						Evt.Damage:InvokeServer(WeaponTool, VitimaHuman, TotalDistTraveled, 2, WeaponData, ModTable, nil, nil, SKP_02)
					elseif HitPart.Name == "Right Leg" or HitPart.Name == "Left Leg" or HitPart.Name == "RightUpperLeg" or HitPart.Name == "RightLowerLeg" or HitPart.Name == "RightFoot" or HitPart.Name == "LeftUpperLeg" or HitPart.Name == "LeftLowerLeg" or HitPart.Name == "LeftFoot" then
						Evt.Damage:InvokeServer(WeaponTool, VitimaHuman, TotalDistTraveled, 3, WeaponData, ModTable, nil, nil, SKP_02)		
					end	
				end
			end
			return
		end

		Bpos2 = Bpos
	end)
end

local Tracers = 0
function ACSActions.TracerCalculation()
	-- Tracer settings support both random-chance tracers and deterministic
	-- "every X shots" tracers.
	if not WeaponData.Tracer and not WeaponData.BulletFlare then return false; end;

	if WeaponData.RandomTracer.Enabled then
		if math.random(1, 100) <= WeaponData.RandomTracer.Chance then return true; end;
		return false;
	end;

	if Tracers >= WeaponData.TracerEveryXShots then
		Tracers = 0;
		return true;
	end;
	Tracers = Tracers + 1;
	return false;
end;

function ACSActions.CreateBullet()
	-- Creates the invisible simulated bullet and optional visual tracer. Damage is
	-- still resolved by CastRay after the projectile moves.

	local Bullet = Instance.new("Part")
	Bullet.Name = plr.Name.."_Bullet"
	Bullet.CanCollide = false
	Bullet.Shape = Enum.PartType.Ball
	Bullet.Transparency = 1
	Bullet.Size = Vector3.new(1,1,1)
	Bullet.Parent = LocalEffectsFolder

	local Origin 		= WeaponInHand.Handle.Muzzle.WorldPosition
	local Direction 	= WeaponInHand.Handle.Muzzle.WorldCFrame.LookVector + (WeaponInHand.Handle.Muzzle.WorldCFrame.UpVector * (((WeaponData.BulletDrop * WeaponData.CurrentZero/4)/WeaponData.MuzzleVelocity))/2)
	if shouldUseThirdPersonImageCrosshair() then
		-- Third-person weapons aim from screen center so bullets follow the visible
		-- crosshair instead of the hidden first-person muzzle orientation.
		Direction = getThirdPersonAimDirection(Origin)
	end
	local BulletCF 		= CFrame.new(Origin, Direction) 
	local WalkMul 		= WeaponData.WalkMult * ModTable.WalkMult
	local balaspread

	if aimming and WeaponData.Bullets <= 1 then
		balaspread = CFrame.Angles(
			math.rad(ACSActions.RAND(-BSpread - (charspeed/1) * WalkMul, BSpread + (charspeed/1) * WalkMul) / (10 * WeaponData.AimSpreadReduction)),
			math.rad(ACSActions.RAND(-BSpread - (charspeed/1) * WalkMul, BSpread + (charspeed/1) * WalkMul) / (10 * WeaponData.AimSpreadReduction)),
			math.rad(ACSActions.RAND(-BSpread - (charspeed/1) * WalkMul, BSpread + (charspeed/1) * WalkMul) / (10 * WeaponData.AimSpreadReduction))
		)
	else
		balaspread = CFrame.Angles(
			math.rad(ACSActions.RAND(-BSpread - (charspeed/1) * WalkMul, BSpread + (charspeed/1) * WalkMul) / 10),
			math.rad(ACSActions.RAND(-BSpread - (charspeed/1) * WalkMul, BSpread + (charspeed/1) * WalkMul) / 10),
			math.rad(ACSActions.RAND(-BSpread - (charspeed/1) * WalkMul, BSpread + (charspeed/1) * WalkMul) / 10)
		)
	end

	Direction = balaspread * Direction

	local Visivel = ACSActions.TracerCalculation()

	if Visivel then
		-- Server bullet replication is kept for other clients; local ProjectileVisuals
		-- gives the shooter immediate feedback.
		if gameRules.ReplicatedBullets then
			Evt.ServerBullet:FireServer(Origin,Direction,WeaponData,ModTable)
		end

		ProjectileVisuals.spawnTracer(Origin, Direction, {
			parent = LocalEffectsFolder,
			weaponData = WeaponData,
			velocityScale = ModTable.MuzzleVelocity,
		})
	end

	local BulletMass = Bullet:GetMass()
	local Force = Vector3.new(0,BulletMass * (196.2) - (WeaponData.BulletDrop) * (196.2), 0)
	local BF = Instance.new("BodyForce")
	BF.Parent = Bullet

	Bullet.CFrame = BulletCF
	Bullet:ApplyImpulse(Direction * WeaponData.MuzzleVelocity * ModTable.MuzzleVelocity)
	BF.Force = Force

	destroyLater(Bullet, 5)

	ACSActions.CastRay(Bullet, Origin)
end


function ACSActions.meleeCast()
	-- Set an origin and directional vector
	local rayOrigin 	= cam.CFrame.Position
	local rayDirection 	= cam.CFrame.LookVector * WeaponData.BladeRange

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = Ignore_Model
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)


	if raycastResult then
		local Hit2 = raycastResult.Instance

		--Check if it's a hat or accessory
		if Hit2 and Hit2.Parent:IsA('Accessory') then
			for _,players in pairs(game.Players:GetPlayers()) do
				if not players.Character then continue; end;
				for _, hats in pairs(players.Character:GetChildren()) do
					if not hats:IsA("Accessory") then continue; end;
					table.insert(Ignore_Model, hats)
				end
			end
			return ACSActions.meleeCast()
		end

		if Hit2 and Hit2.Name == "Ignorable" or Hit2.Name == "Glass" or Hit2.Name == "Ignore" or Hit2.Parent.Name == "Top" or Hit2.Parent.Name == "Helmet" or Hit2.Parent.Name == "Up" or Hit2.Parent.Name == "Down" or Hit2.Parent.Name == "Face" or Hit2.Parent.Name == "Olho" or Hit2.Parent.Name == "Headset" or Hit2.Parent.Name == "Numero" or Hit2.Parent.Name == "Vest" or Hit2.Parent.Name == "Chest" or Hit2.Parent.Name == "Waist" or Hit2.Parent.Name == "Back" or Hit2.Parent.Name == "Belt" or Hit2.Parent.Name == "Leg1" or Hit2.Parent.Name == "Leg2" or Hit2.Parent.Name == "Arm1"  or Hit2.Parent.Name == "Arm2" then
			table.insert(Ignore_Model, Hit2)
			return ACSActions.meleeCast()
		end

		if Hit2 and Hit2.Parent.Name == "Top" or Hit2.Parent.Name == "Helmet" or Hit2.Parent.Name == "Up" or Hit2.Parent.Name == "Down" or Hit2.Parent.Name == "Face" or Hit2.Parent.Name == "Olho" or Hit2.Parent.Name == "Headset" or Hit2.Parent.Name == "Numero" or Hit2.Parent.Name == "Vest" or Hit2.Parent.Name == "Chest" or Hit2.Parent.Name == "Waist" or Hit2.Parent.Name == "Back" or Hit2.Parent.Name == "Belt" or Hit2.Parent.Name == "Leg1" or Hit2.Parent.Name == "Leg2" or Hit2.Parent.Name == "Arm1"  or Hit2.Parent.Name == "Arm2" then
			table.insert(Ignore_Model, Hit2.Parent)
			return ACSActions.meleeCast()
		end

		if Hit2 and (Hit2.Transparency >= 1 or Hit2.CanCollide == false) and Hit2.Name ~= 'Head' and Hit2.Name ~= 'Right Arm' and Hit2.Name ~= 'Left Arm' and Hit2.Name ~= 'Right Leg' and Hit2.Name ~= 'Left Leg' and Hit2.Name ~= "UpperTorso" and Hit2.Name ~= "LowerTorso" and Hit2.Name ~= "RightUpperArm" and Hit2.Name ~= "RightLowerArm" and Hit2.Name ~= "RightHand" and Hit2.Name ~= "LeftUpperArm" and Hit2.Name ~= "LeftLowerArm" and Hit2.Name ~= "LeftHand" and Hit2.Name ~= "RightUpperLeg" and Hit2.Name ~= "RightLowerLeg" and Hit2.Name ~= "RightFoot" and Hit2.Name ~= "LeftUpperLeg" and Hit2.Name ~= "LeftLowerLeg" and Hit2.Name ~= "LeftFoot" and Hit2.Name ~= 'Armor' and Hit2.Name ~= 'EShield' then
			table.insert(Ignore_Model, Hit2)
			return ACSActions.meleeCast()
		end
	end


	if not raycastResult then return; end;
	local FoundHuman,VitimaHuman = ACSActions.CheckForHumanoid(raycastResult.Instance)
	HitMod.HitEffect(Ignore_Model, raycastResult.Position, raycastResult.Instance , raycastResult.Normal, raycastResult.Material, WeaponData)
	Evt.HitEffect:FireServer(raycastResult.Position, raycastResult.Instance , raycastResult.Normal, raycastResult.Material, WeaponData)

	local HitPart = raycastResult.Instance

	if not FoundHuman or VitimaHuman.Health <= 0 then return; end;
	local SKP_02 = SKP_01.."-"..plr.UserId

	if HitPart.Name == "Head" or HitPart.Parent.Name == "Top" or HitPart.Parent.Name == "Headset" or HitPart.Parent.Name == "Olho" or HitPart.Parent.Name == "Face" or HitPart.Parent.Name == "Numero" then
		Thread:Spawn(function()
			Evt.Damage:InvokeServer(WeaponTool, VitimaHuman, 0, 1, WeaponData, ModTable, nil, nil, SKP_02)	
		end)

	elseif HitPart.Name == "Torso" or HitPart.Name == "UpperTorso" or HitPart.Name == "LowerTorso" or HitPart.Parent.Name == "Chest" or HitPart.Parent.Name == "Waist" or HitPart.Name == "RightUpperArm" or HitPart.Name == "RightLowerArm" or HitPart.Name == "RightHand" or HitPart.Name == "LeftUpperArm" or HitPart.Name == "LeftLowerArm" or HitPart.Name == "LeftHand" then
		Thread:Spawn(function()
			Evt.Damage:InvokeServer(WeaponTool, VitimaHuman, 0, 2, WeaponData, ModTable, nil, nil, SKP_02)	
		end)

	elseif HitPart.Name == "Right Arm" or HitPart.Name == "Right Leg" or HitPart.Name == "Left Leg" or HitPart.Name == "Left Arm" or HitPart.Name == "RightUpperLeg" or HitPart.Name == "RightLowerLeg" or HitPart.Name == "RightFoot" or HitPart.Name == "LeftUpperLeg" or HitPart.Name == "LeftLowerLeg" or HitPart.Name == "LeftFoot" then
		Thread:Spawn(function()
			Evt.Damage:InvokeServer(WeaponTool, VitimaHuman, 0, 3, WeaponData, ModTable, nil, nil, SKP_02)	
		end)
	end;		
end;

function ACSActions.UpdateGui()
	-- Update both bridges: Player attributes for React, and SE_GUI for the current
	-- weapon HUD adapter.
	if WeaponData then
		WeaponData.AmmoInGun = Ammo
		WeaponData.StoredAmmo = StoredAmmo
		WeaponUIState.publishHud(plr, WeaponData, Ammo, StoredAmmo, SafeMode)
		updateThirdPersonCrosshair()
		WeaponHudAdapter.update(SE_GUI, WeaponData, Ammo, StoredAmmo, SafeMode, Suppressor, BipodAtt, Sens)
	end
end

function ACSActions.Grenade()
	-- Grenades are feature-flagged off for now, but the old function remains as a
	-- placeholder until the dedicated grenade rewrite lands.
	if GRDebounce then return; end;
	GRDebounce = true;
	ACSActions.GrenadeReady()
end

function ACSActions.TossGrenade()
	if not WeaponTool or not WeaponData or not GRDebounce then return; end;
	local SKP_02 = SKP_01.."-"..plr.UserId
	ACSActions.GrenadeThrow()
	if not WeaponTool or not WeaponData then return; end;
	Evt.Grenade:FireServer(WeaponTool,WeaponData,cam.CFrame,cam.CFrame.LookVector,Power,SKP_02)
	ACSActions.unset()
end

function ACSActions.GrenadeMode()
	if Power >= 150 then
		Power = 100
		WeaponHudAdapter.setGrenadeForceText(SE_GUI, "Mid Throw")
	elseif Power >= 100 then
		Power = 50
		WeaponHudAdapter.setGrenadeForceText(SE_GUI, "Low Throw")
	elseif Power >= 50 then
		Power = 150
		WeaponHudAdapter.setGrenadeForceText(SE_GUI, "High Throw")
	end
end

function ACSActions.JamChance()
	-- JamController only decides the roll; Main still owns the click sound and
	-- weapon data mutation.
	if JamController.roll(WeaponData, { ammo = Ammo }, math.random) then
		WeaponInHand.Handle.Click:Play()
	end
end

function ACSActions.Jammed()
	if not JamController.canClear(WeaponData) then return; end;
	mouse1down = false
	reloading = true
	SafeMode = false
	GunStance = 0
	Evt.GunStance:FireServer(GunStance,AnimData)
	ACSActions.UpdateGui()

	ACSActions.JammedAnim()
	WeaponData.Jammed = false
	ACSActions.UpdateGui()
	reloading = false
	ACSActions.RunCheck()
end

function ACSActions.Reload()
	-- Reload timing/animation remains here because weapon animation modules yield
	-- internally. Ammo math itself is delegated to ReloadController.
	if ReloadController.canReload(WeaponData, { ammo = Ammo, storedAmmo = StoredAmmo }) then

		mouse1down = false
		reloading = true
		SafeMode = false
		GunStance = 0
		Evt.GunStance:FireServer(GunStance,AnimData)
		ACSActions.UpdateGui()

		if WeaponData.ShellInsert then
			if Ammo > 0 then
				for _ = 1,WeaponData.Ammo - Ammo do
					if StoredAmmo > 0 and Ammo < WeaponData.Ammo then
						if CancelReload then
							break
						end
						ACSActions.ReloadAnim()
						local nextAmmo = ReloadController.insertOne({ ammo = Ammo, storedAmmo = StoredAmmo })
						Ammo = nextAmmo.ammo
						StoredAmmo = nextAmmo.storedAmmo
						ACSActions.UpdateGui()
					end
				end
			else
				ACSActions.TacticalReloadAnim()
				local firstInsert = ReloadController.insertOne({ ammo = Ammo, storedAmmo = StoredAmmo })
				Ammo = firstInsert.ammo
				StoredAmmo = firstInsert.storedAmmo
				ACSActions.UpdateGui()
				for _ = 1,WeaponData.Ammo - Ammo do
					if StoredAmmo > 0 and Ammo < WeaponData.Ammo then
						if CancelReload then
							break
						end
						ACSActions.ReloadAnim()
						local nextAmmo = ReloadController.insertOne({ ammo = Ammo, storedAmmo = StoredAmmo })
						Ammo = nextAmmo.ammo
						StoredAmmo = nextAmmo.storedAmmo
						ACSActions.UpdateGui()
					end
				end

			end
		else
			if Ammo > 0 then
				ACSActions.ReloadAnim()
			else
				ACSActions.TacticalReloadAnim()
			end

			local nextAmmo = ReloadController.finishMagazineReload(WeaponData, { ammo = Ammo, storedAmmo = StoredAmmo })
			Ammo = nextAmmo.ammo
			StoredAmmo = nextAmmo.storedAmmo
		end
		CancelReload = false
		reloading = false
		ACSActions.RunCheck()
		ACSActions.UpdateGui()
	end
end

function ACSActions.GunFx()
	-- FireEffectsController returns updated spread/recoil counters so Main can
	-- keep using them for bullet spread and recoil recovery.
	local nextState = FireEffectsController.apply(WeaponInHand, WeaponData, ModTable, Ammo, Suppressor, FlashHider, {
		bSpread = BSpread,
		recoilPower = RecoilPower,
		generateBullet = generateBullet,
		lastSpreadUpdate = LastSpreadUpdate,
	})

	BSpread = nextState.bSpread
	RecoilPower = nextState.recoilPower
	generateBullet = nextState.generateBullet
	LastSpreadUpdate = nextState.lastSpreadUpdate
end

function ACSActions.Shoot()
	-- ShootingController controls sequencing, while these callbacks preserve the
	-- old ACS side effects: remotes, bullet spawning, ammo decrement, jam rolls,
	-- recoil, and HUD refresh.
	local shotState = {
		ammo = Ammo,
		shooting = shooting,
		reloading = reloading,
		runKeyDown = runKeyDown,
		safeMode = SafeMode,
		checkingMag = CheckingMag,
		mouseDown = mouse1down,
	}

	local function setShooting(value: boolean)
		shooting = value
		shotState.shooting = value
	end

	local function setMouseDown(value: boolean)
		mouse1down = value
		shotState.mouseDown = value
	end

	local function fireRound()
		-- One confirmed shot can create multiple pellets/projectiles depending on
		-- WeaponData.Bullets.
		if not WeaponData then return; end;
		Evt.Atirar:FireServer(WeaponTool,Suppressor,FlashHider)
		for _ =  1, WeaponData.Bullets do
			Thread:Spawn(ACSActions.CreateBullet)
		end
		Ammo = Ammo - 1
		shotState.ammo = Ammo
		ACSActions.GunFx()
		ACSActions.JamChance()
		ACSActions.UpdateGui()
		Thread:Spawn(ACSActions.Recoil)
	end

	ShootingController.shoot(WeaponData, shotState, {
		setShooting = setShooting,
		setMouseDown = setMouseDown,
		isMouseDown = function()
			return mouse1down
		end,
		fireRound = fireRound,
		firePumpRound = function()
			if not WeaponData then return; end;
			Evt.Atirar:FireServer(WeaponTool,Suppressor,FlashHider)
			for _ =  1, WeaponData.Bullets do
				Thread:Spawn(ACSActions.CreateBullet)
			end
			Ammo = Ammo - 1
			shotState.ammo = Ammo
			ACSActions.GunFx()
			ACSActions.UpdateGui()
			Thread:Spawn(ACSActions.Recoil)
		end,
		playEmptyClick = function()
			WeaponInHand.Handle.Click:Play()
		end,
		pump = ACSActions.PumpAnim,
		runCheck = ACSActions.RunCheck,
		melee = function()
			ACSActions.meleeCast()
			ACSActions.meleeAttack()
		end,
		schedule = schedule,
	})
end

local CameraLeanController = {}

local LeanSpring = {}
LeanSpring.cornerPeek = SpringMod.new(0)
LeanSpring.cornerPeek.d = 1
LeanSpring.cornerPeek.s = 20
LeanSpring.peekFactor = math.rad(-15)
LeanSpring.dirPeek = 0

function CameraLeanController.Update()

	LeanSpring.cornerPeek.t = LeanSpring.peekFactor * Virar
	local NewLeanCF = CFrame.fromAxisAngle(Vector3.new(0, 0, 1), LeanSpring.cornerPeek.p)
	cam.CFrame = cam.CFrame * NewLeanCF
end

game:GetService("RunService"):BindToRenderStep("Camera Update", 200, CameraLeanController.Update)

function ACSActions.RunCheck()
	if runKeyDown then
		mouse1down = false
		GunStance = 3
		Evt.GunStance:FireServer(GunStance,AnimData)
		ACSActions.SprintAnim()
	else
		if aimming then
			GunStance = 2
			Evt.GunStance:FireServer(GunStance,AnimData)
		else
			GunStance = 0
			Evt.GunStance:FireServer(GunStance,AnimData)
		end
		ACSActions.IdleAnim()
	end
end

function ACSActions.Stand()
	Stance:FireServer(Stances,Virar)
	tweenStanceCameraOffset()
	StanceController.applyStand(getStanceContext(), Steady)
end

function ACSActions.Crouch()
	Stance:FireServer(Stances,Virar)
	tweenStanceCameraOffset()
	StanceController.applyCrouch(getStanceContext())
end

--function Prone()
--	Stance:FireServer(Stances,Virar)
--	TS:Create(char.Humanoid, TweenInfo.new(.3), {CameraOffset = Vector3.new(CameraX,CameraY,char.Humanoid.CameraOffset.Z)} ):Play()



--	if ACS_Client:GetAttribute("Surrender") then
--		char.Humanoid.WalkSpeed = 0
--	else
--		char.Humanoid.WalkSpeed = gameRules.ProneWalksSpeed
--	end

--	char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
--	IsStanced = true
--end

--function Lean()
--	TS:Create(char.Humanoid, TweenInfo.new(.3), {CameraOffset = Vector3.new(CameraX,CameraY,char.Humanoid.CameraOffset.Z)} ):Play()
--	Stance:FireServer(Stances,Virar)


--end

----------//Animation Loader\\----------
local function getAnimationContext()
	return {
		RArmWeld,
		LArmWeld,
		GunWeld,
		WeaponInHand,
		ViewModel,
	}
end

local function playWeaponAnimation(animationName)
	if not AnimData then
		warn(("[ACS Animation] Tried to play %s before AnimData was loaded."):format(animationName))
		return false
	end

	local animation = AnimData[animationName]
	if typeof(animation) ~= "function" then
		warn(("[ACS Animation] Missing animation function: %s"):format(animationName))
		return false
	end

	return AnimationRunner.run(animationName, function()
		animation(getAnimationContext())
	end)
end

function ACSActions.EquipAnim()
	AnimDebounce = false
	playWeaponAnimation("EquipAnim")
	AnimDebounce = true
end

function ACSActions.IdleAnim()
	playWeaponAnimation("IdleAnim")
	AnimDebounce = true
end

function ACSActions.SprintAnim()
	AnimDebounce = false
	playWeaponAnimation("SprintAnim")
end

function ACSActions.HighReady()
	playWeaponAnimation("HighReady")
end

function ACSActions.LowReady()
	playWeaponAnimation("LowReady")
end

function ACSActions.Patrol()
	playWeaponAnimation("Patrol")
end

function ACSActions.ReloadAnim()
	playWeaponAnimation("ReloadAnim")
end

function ACSActions.TacticalReloadAnim()
	playWeaponAnimation("TacticalReloadAnim")
end

function ACSActions.JammedAnim()
	playWeaponAnimation("JammedAnim")
end

function ACSActions.PumpAnim()
	reloading = true
	playWeaponAnimation("PumpAnim")
	reloading = false
end

function ACSActions.meleeAttack()
	playWeaponAnimation("meleeAttack")
end

function ACSActions.GrenadeReady()
	playWeaponAnimation("GrenadeReady")
end

function ACSActions.GrenadeThrow()
	playWeaponAnimation("GrenadeThrow")
end
----------//Animation Loader\\----------

----------//KeyBinds\\----------
InputBindings.bindDefaultActions(CAS, ACSActions.handleAction)
--CAS:BindAction("LeanLeft", ACSActions.handleAction, false, Enum.KeyCode.Q)
--CAS:BindAction("LeanRight", ACSActions.handleAction, false, Enum.KeyCode.E)
----------//KeyBinds\\----------

----------//Gun System\\----------
char.ChildAdded:Connect(function(Tool)
	local toolData = WeaponToolClassifier.readSettings(Tool)
	if Tool:IsA('Tool') and Humanoid.Health > 0 and not ToolEquip and WeaponToolClassifier.canEquip(toolData, FeatureFlags) then
		local L_370_ = true
		if char:WaitForChild('Humanoid').Sit and char.Humanoid.SeatPart:IsA("VehicleSeat") or char:WaitForChild('Humanoid').Sit and char.Humanoid.SeatPart:IsA("VehicleSeat") then
			L_370_ = false;
		end

		if L_370_ then
			if not ToolEquip then
				--pcall(function()
				ACSActions.setup(Tool)
				--end)

			elseif ToolEquip then
				pcall(function()
					ACSActions.unset()
					ACSActions.setup(Tool)
				end)
			end;
		end;
	end

end)

char.ChildRemoved:Connect(function(Tool)
	if Tool == WeaponTool then
		if ToolEquip then
			ACSActions.unset()
		end
	end
end)

Humanoid.Running:Connect(function(speed)
	charspeed = speed
	if speed > 0.1 then
		running = true
	else
		running = false
	end
end)

Humanoid.Swimming:Connect(function(speed)
	if Swimming then
		charspeed = speed
		if speed > 0.1 then
			running = true
		else
			running = false
		end
	end
end)

Humanoid.Died:Connect(function()
	TS:Create(char.Humanoid, TweenInfo.new(1), {CameraOffset = Vector3.new(0,0,0)} ):Play()
	ChangeStance = false
	ACSActions.Stand()
	Stances = 0
	Virar = 0
	CameraX = 0
	CameraY = 0
	--Lean()
	ACSActions.unset()
end)

Humanoid.Seated:Connect(function(IsSeated, Seat)

	if IsSeated and Seat and (Seat:IsA("VehicleSeat")) then
		ACSActions.unset()
		Humanoid:UnequipTools()
		plr.CameraMaxZoomDistance = gameRules.VehicleMaxZoom
	else
		plr.CameraMaxZoomDistance = game.StarterPlayer.CameraMaxZoomDistance
	end

	if IsSeated  then
		Sentado = true
		Stances = 0
		Virar = 0
		CameraX = 0
		CameraY = 0
		ACSActions.Stand()
		--Lean()
	else
		Sentado = false
	end
end)

Humanoid.Changed:Connect(function(Property)
	if not  gameRules.AntiBunnyHop then return; end;
	if Property == "Jump" and Humanoid.Sit == true and Humanoid.SeatPart ~= nil then
		Humanoid.Sit = false
	elseif Property == "Jump" and Humanoid.Sit == false then
		if JumpDelay then
			Humanoid.Jump = false
			return false
		end
		JumpDelay = true
		schedule(gameRules.JumpCoolDown, function()
			JumpDelay = false
		end, "ACS:JumpCooldown")
	end
end)

Humanoid.StateChanged:Connect(function(_oldState,state)
	if state == Enum.HumanoidStateType.Swimming then
		Swimming = true
		Stances = 0
		Virar = 0
		CameraX = 0
		CameraY = 0
		ACSActions.Stand()
		--Lean()
	else
		Swimming = false
	end

	FallDamage:handleStateChanged(state)

end)

mouse.WheelBackward:Connect(function() -- fires when the wheel goes forwards

	if ToolEquip and not CheckingMag and not aimming and not reloading and not runKeyDown and AnimDebounce and WeaponData.Type == "Gun" then
		mouse1down = false
		if GunStance == 0 then
			SafeMode = true
			GunStance = -1
			ACSActions.UpdateGui()
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.LowReady()
		elseif GunStance == -1 then
			SafeMode = true
			GunStance = -2
			ACSActions.UpdateGui()
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.Patrol()
		elseif GunStance == 1 then
			SafeMode = false
			GunStance = 0
			ACSActions.UpdateGui()
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.IdleAnim()
		end
	end

	if ToolEquip and aimming and Sens > 5 then
		Sens = Sens - 5
		ACSActions.UpdateGui()
		game:GetService('UserInputService').MouseDeltaSensitivity = (Sens/100)
	end

end)


mouse.WheelForward:Connect(function() -- fires when the wheel goes backwards

	if ToolEquip and not CheckingMag and not aimming and not reloading and not runKeyDown and AnimDebounce and WeaponData.Type == "Gun" then
		mouse1down = false
		if GunStance == 0 then
			SafeMode = true
			GunStance = 1
			ACSActions.UpdateGui()
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.HighReady()
		elseif GunStance == -1 then
			SafeMode = false
			GunStance = 0
			ACSActions.UpdateGui()
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.IdleAnim()
		elseif GunStance == -2 then
			SafeMode = true
			GunStance = -1
			ACSActions.UpdateGui()
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.LowReady()
		end
	end

	if ToolEquip and aimming and Sens < 100 then
		Sens = Sens + 5
		ACSActions.UpdateGui()
		game:GetService('UserInputService').MouseDeltaSensitivity = (Sens/100)
	end

end)

hostScript.Parent:GetAttributeChangedSignal("Injured"):Connect(function()
	local valor = hostScript.Parent:GetAttribute("Injured")

	if valor and runKeyDown then
		runKeyDown 	= false
		ACSActions.Stand()
		if not CheckingMag and not reloading and WeaponData and WeaponData.Type ~= "Grenade" and (GunStance == 0 or GunStance == 2 or GunStance == 3) then
			GunStance = 0
			Evt.GunStance:FireServer(GunStance,AnimData)
			ACSActions.IdleAnim()
		end
	end

	if Stances == 0 then
		ACSActions.Stand()
	elseif Stances == 1 then
		ACSActions.Crouch()
	end

end)

----------//Gun System\\----------

----------//Collapse\\----------
ACS_Client:GetAttributeChangedSignal("Collapsed"):Connect(function()
	if not ACS_Client:GetAttribute("Collapsed") then return; end;
	runKeyDown 	= true
	ACSActions.Stand()
	Stances = 0
	Virar = 0
	CameraX = 0
	CameraY = 0
	--Lean()
end)

Run.RenderStepped:Connect(function(_deltaTime)
	-- Render loop is the final pose compositor. By this point input, animations,
	-- recoil, camera mode, and procedural layers have all updated their state.
	ACSActions.HeadMovement()
	ACSActions.renderCam()

	if ViewModel and LArm and RArm and WeaponInHand then --Check if the weapon and arms are loaded
		local thirdPersonCamera = isThirdPersonCamera()
		setViewModelVisible(not thirdPersonCamera)

		local mouseDelta = User:GetMouseDelta()
		if not aimming then
			-- Camera sway is disabled while aiming so ADS stays centered.
			SwaySpring:accelerate(Vector3.new(mouseDelta.x/60, mouseDelta.y/60, 0))
		end

		local swayVec = SwaySpring.p
		local XSSWY = swayVec.X
		local YSSWY = swayVec.Y
		local Sway = CFrame.Angles(YSSWY,XSSWY,XSSWY)

		if FeatureFlags.WeaponUtilitiesEnabled and BipodAtt then
			-- Bipod support is currently disabled by feature flag, but the old
			-- positioning logic is retained for a future utility rewrite.

			local bipodResult = Runtime.raycast(UnderBarrelAtt.Main.Position, Vector3.new(0,-1.75,0), Ignore_Model)
			local BipodHit = bipodResult and bipodResult.Instance
			local BipodPos = bipodResult and bipodResult.Position

			if BipodHit and BipodPos then
				CanBipod = true
				if CanBipod and BipodActive and not runKeyDown and (GunStance == 0 or GunStance == 2) then
					if not aimming then
						BipodCF = BipodCF:Lerp(CFrame.new(0,(((UnderBarrelAtt.Main.Position - BipodPos).magnitude)-1) * (-1.5), 0),.2)
					else
						BipodCF = BipodCF:Lerp(CFrame.new(),.2)
					end				

				else
					BipodActive = false
					BipodCF = BipodCF:Lerp(CFrame.new(),.2)
				end
			else
				BipodActive = false
				CanBipod = false
				BipodCF = BipodCF:Lerp(CFrame.new(),.2)
			end

		end

		AnimPart.CFrame = cam.CFrame * NearZ * BipodCF * maincf * gunbobcf * aimcf

		if not AnimData.GunModelFixed then
			-- Weapon model follows the viewmodel root plus the gun offset supplied
			-- by ACS_Animations/procedural pose updates.
			WeaponInHand:SetPrimaryPartCFrame(
				ViewModel.PrimaryPart.CFrame
					* guncf
			)
		end

		if running then
			gunbobcf = gunbobcf:Lerp(CFrame.new(
				0.025 * (charspeed/10) * math.sin(tick() * 8),
				0.025 * (charspeed/10) * math.cos(tick() * 16),
				0
				) * CFrame.Angles(
					math.rad( 1 * (charspeed/10) * math.sin(tick() * 16) ), 
					math.rad( 1 * (charspeed/10) * math.cos(tick() * 8) ), 
					math.rad(0)
				), 0.1)
		else
			gunbobcf = gunbobcf:Lerp(CFrame.new(
				0.005 * math.sin(tick() * 1.5),
				0.005 * math.cos(tick() * 2.5),
				0 
				), 0.1)
		end

		if CurAimpart and aimming and AnimDebounce and not CheckingMag then
			-- First-person ADS aligns the camera-attached viewmodel to AimPart.
			-- Third-person keeps camera FOV stable and relies on crosshair aiming.
			if not NVG or WeaponInHand.AimPart:FindFirstChild("NVAim") == nil then
				if AimPartMode == 1 then
					if not isThirdPersonCamera() then
						TS:Create(cam,AimTween,{FieldOfView = ModTable.ZoomValue}):Play()
					end
					maincf = maincf:Lerp(maincf * CFrame.new(0,0,-.5) * recoilcf * Sway:inverse() * CurAimpart.CFrame:toObjectSpace(cam.CFrame), 0.2)
				else
					if not isThirdPersonCamera() then
						TS:Create(cam,AimTween,{FieldOfView = ModTable.Zoom2Value}):Play()
					end
					maincf = maincf:Lerp(maincf * CFrame.new(0,0,-.5) * recoilcf * Sway:inverse() * CurAimpart.CFrame:toObjectSpace(cam.CFrame), 0.2)
				end
			else
				if not isThirdPersonCamera() then
					TS:Create(cam,AimTween,{FieldOfView = 70}):Play()
				end
				maincf = maincf:Lerp(maincf * CFrame.new(0,0,-.5) * recoilcf * Sway:inverse() * (WeaponInHand.AimPart.CFrame * WeaponInHand.AimPart.NVAim.CFrame):toObjectSpace(cam.CFrame), 0.2)
			end

		else
			if not isThirdPersonCamera() then
				TS:Create(cam,AimTween,{FieldOfView = 70}):Play()
			end
			maincf = maincf:Lerp(AnimData.MainCFrame * recoilcf * Sway:inverse(), 0.2)
		end

		for _, Part in pairs(WeaponInHand:GetDescendants()) do
			-- Scope/reticle UI is parallax-corrected by shifting the SurfaceGui
			-- according to camera position relative to the sight mark.
			if Part:IsA("BasePart") and Part.Name == "SightMark" then
				local dist_scale = Part.CFrame:pointToObjectSpace(cam.CFrame.Position)/Part.Size
				local reticle = Part.SurfaceGui.Border.Scope	
				reticle.Position=UDim2.new(.5+dist_scale.x,0,.5-dist_scale.y,0)	
			end
		end

		recoilcf = recoilcf:Lerp(CFrame.new() * CFrame.Angles( math.rad(RecoilSpring.p.X), math.rad(RecoilSpring.p.Y), math.rad(RecoilSpring.p.z)), 0.2)


		updateThirdPersonCrosshair()

		if BSpread then
			local currTime = time()
			if currTime - LastSpreadUpdate > (60/WeaponData.ShootRate) * 2 and not shooting and BSpread > WeaponData.MinSpread * ModTable.MinSpread then
				BSpread = math.max(WeaponData.MinSpread * ModTable.MinSpread, BSpread - WeaponData.AimInaccuracyDecrease * ModTable.AimInaccuracyDecrease)
			end
			if currTime - LastSpreadUpdate > (60/WeaponData.ShootRate) * 1.5 and not shooting and RecoilPower > WeaponData.MinRecoilPower * ModTable.MinRecoilPower then
				RecoilPower =  math.max(WeaponData.MinRecoilPower * ModTable.MinRecoilPower, RecoilPower - WeaponData.RecoilPowerStepAmount * ModTable.RecoilPowerStepAmount)
			end
		end

		if LaserActive and Pointer ~= nil then

			if NVG then
				Pointer.Transparency = 0
				Pointer.Beam.Enabled = true
			else
				if not gameRules.RealisticLaser then
					Pointer.Beam.Enabled = true
				else
					Pointer.Beam.Enabled = false
				end
				if IRmode then
					Pointer.Transparency = 1
				else
					Pointer.Transparency = 0
				end
			end

			for _, Key in pairs(WeaponInHand:GetDescendants()) do
				if Key:IsA("BasePart") and Key.Name == "LaserPoint" then
					local laserResult = Runtime.raycast(Key.CFrame.Position, Key.CFrame.LookVector * 1000, Ignore_Model)
					local Pos = laserResult and laserResult.Position or (cam.CFrame.Position + Key.CFrame.LookVector * 2000)
					local Normal = laserResult and laserResult.Normal or Key.CFrame.LookVector

					Pointer.CFrame = CFrame.new(Pos, Pos + Normal)

					if HalfStep and gameRules.ReplicatedLaser then
						Evt.SVLaser:FireServer(Pos,1,Pointer.Color,IRmode,WeaponTool)
					end
					break
				end
			end
		end
	end
end)
----------//Render Functions\\----------

----------//Events\\----------
Evt.Refil.OnClientEvent:Connect(function(Tool, Infinite, Stored)

	local data = require(Tool.ACS_Settings)
	if Infinite then
		local configuredReserve = if typeof(data.StoredAmmo) == "number" then data.StoredAmmo else StoredAmmo
		local maxReserve = if typeof(data.MaxStoredAmmo) == "number" then data.MaxStoredAmmo else configuredReserve
		if maxReserve == math.huge then
			StoredAmmo = math.max(StoredAmmo, configuredReserve)
		else
			StoredAmmo = maxReserve
		end
		data.StoredAmmo = StoredAmmo
		ACSActions.UpdateGui()
		return
	end

	local NewStored = math.min(data.MaxStoredAmmo - StoredAmmo, Stored.Value) 

	StoredAmmo = StoredAmmo + NewStored
	data.StoredAmmo = StoredAmmo

	ACSActions.UpdateGui()

	if not Infinite then
		Evt.Refil:FireServer(Stored, NewStored)
	end

end)
----------//Events\\----------

end

return Main


