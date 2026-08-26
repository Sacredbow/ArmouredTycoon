--!strict
--[[
	@class Main

	@desc
	Thin orchestrator for the client-side ACS weapon framework (~800 lines).
	Owns the render loop, event wiring, and character lifecycle.
	Delegates all domain logic to focused controllers:

	Core/AnimationController.luau  — weapon animation playback
	Core/CameraController.luau      — neck rotation, camera springs, viewmodel visibility
	Core/CastController.luau        — bullet creation, ray casting, hit detection, melee
	Core/CrosshairController.luau   — manual crosshair GUI + React UI bridge
	Core/EquipController.luau       — equip/unequip lifecycle, ammo, attachments, modifiers
	Core/InputController.luau       — weapon-specific CAS bindings + mouse wheel
	Core/RenderController.luau      — viewmodel render pipeline (bob, sway, bipod, ADS, laser)
	Core/InputBindings.luau         — default movement bindings
	Core/FeatureFlags.luau          — feature toggles
	Core/WeaponToolClassifier.luau  — ACS_Settings reader + equip guard
	Core/Runtime.luau               — camera, effects folder, raycast, randomRange helpers

	Actions/  — firing/reload/jam/stance/fall-damage rules
	Combat/   — attachments, recoil, hit-region mapping
	UI/       — WeaponHudAdapter, WeaponUIState, StatusEffectsGui
	WeaponAnimation/ — procedural pose layers, ACS animation runner
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")
const ContextActionService = game:GetService("ContextActionService")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const PlayersService = game:GetService("Players")

--// Modules

local RuntimeSettings = require(ReplicatedStorage.Modules.SettingsManager.RuntimeSettings)
local ECS = require(ReplicatedStorage.ECS)

local Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
local Events = Engine:WaitForChild("Events")
local Mods = Engine:WaitForChild("Modules")
local HUDs = Engine:WaitForChild("HUD")
local ArmModel = Engine:WaitForChild("ArmModel")
local GunModels = Engine:WaitForChild("GunModels")
local AttModels = Engine:WaitForChild("AttModels")
local AttModules = Engine:WaitForChild("AttModules")
local Rules = Engine:WaitForChild("GameRules")

local gameRules = require(Rules:WaitForChild("Config"))
local SpringMod = require(Mods:WaitForChild("Spring"))
local HitMod = require(Mods:WaitForChild("Hitmarker"))
local Thread = require(Mods:WaitForChild("Thread"))

--// Controllers

local Runtime = require(script.Parent.Core.Runtime)
local FeatureFlags = require(script.Parent.Core.FeatureFlags)
local InputBindings = require(script.Parent.Core.InputBindings)
local WeaponToolClassifier = require(script.Parent.Core.WeaponToolClassifier)
local InputController = require(script.Parent.Core.InputController)
local EquipController = require(script.Parent.Core.EquipController)
local CameraController = require(script.Parent.Core.CameraController)
local CrosshairController = require(script.Parent.Core.CrosshairController)
local CastController = require(script.Parent.Core.CastController)
local RenderController = require(script.Parent.Core.RenderController)

--// Action / Combat / UI Modules

local AttachmentModifiers = require(script.Parent.Combat.AttachmentModifiers)
local AttachmentController = require(script.Parent.Combat.AttachmentController)
local RecoilController = require(script.Parent.Combat.RecoilController)
local FireEffectsController = require(script.Parent.Actions.FireEffectsController)
local FiremodeController = require(script.Parent.Actions.FiremodeController)
local JamController = require(script.Parent.Actions.JamController)
local ReloadController = require(script.Parent.Actions.ReloadController)
local ShootingController = require(script.Parent.Actions.ShootingController)
local StanceController = require(script.Parent.Actions.StanceController)
local WeaponHudAdapter = require(script.Parent.UI.WeaponHudAdapter)
local WeaponUIState = require(script.Parent.UI.WeaponUIState)
local StatusEffectsGui = require(script.Parent.UI.StatusEffectsGui)

--// Micro-Optimisations

const CFrame_new = CFrame.new
const CFrame_Angles = CFrame.Angles
const math_rad = math.rad
const math_sin = math.sin
const math_cos = math.cos
const math_clamp = math.clamp
const math_min = math.min
const math_max = math.max
const math_random = math.random
const time = time
const tick = tick
const string_find = string.find
const string_lower = string.lower

local Main = {}

function Main.start(hostScript)
	local plr = PlayersService.LocalPlayer :: Player
	local char = hostScript:FindFirstAncestorOfClass("Model")
	if not char then
		error("[ACS] Character model ancestor was not found")
	end

	local mouse = plr:GetMouse()
	local cam = Runtime.getCurrentCamera()
	local acsClient = char:FindFirstChild("ACS_Client")
	if not acsClient then
		error("[ACS] ACS_Client was not found under character")
	end

	local effectsFolder = Runtime.getEffectsFolder(char)

	-- Raycast ignore list
	local ignoreModel = { cam, char, effectsFolder }
	local IGNORE_MODEL_MAX = 200
	local function addIgnore(inst: Instance)
		if #ignoreModel > IGNORE_MODEL_MAX then
			table.remove(ignoreModel, 4)
		end
		table.insert(ignoreModel, inst)
	end

	-- Connection lifecycle
	local connections: { RBXScriptConnection } = {}
	local function connect(sig: RBXScriptConnection)
		table.insert(connections, sig)
		return sig
	end

	local function destroyLater(inst: Instance, lifetime: number)
		task.delay(lifetime, function()
			if inst and inst.Parent then
				inst:Destroy()
			end
		end)
	end

	local function schedule(delay: number, callback: () -> (), name: string?)
		ECS.createEntity({
			Name = name or "ACSClientScheduledTask",
			ScheduledTask = {
				delay = delay,
				elapsed = 0,
				callback = callback,
			},
		})
	end

	--// Character Parts

	local humanoid = char:WaitForChild("Humanoid")
	local torso = char:WaitForChild("Torso")
	local rootPart = char:WaitForChild("HumanoidRootPart")
	local neck = torso:WaitForChild("Neck")
	local authToken = Events.AcessId:InvokeServer(plr.UserId) :: typeof(PlayersService.LocalPlayer)
	

	--// Springs

	local recoilSpring = SpringMod.new(Vector3.new())
	recoilSpring.d = 0.1
	recoilSpring.s = 20

	local cameraSpring = SpringMod.new(Vector3.new())
	cameraSpring.d = 0.5
	cameraSpring.s = 20

	local swaySpring = SpringMod.new(Vector3.new())
	swaySpring.d = 0.25
	swaySpring.s = 20

	--// Lean Spring

	local leanSpring = {}
	leanSpring.cornerPeek = SpringMod.new(0)
	leanSpring.cornerPeek.d = 1
	leanSpring.cornerPeek.s = 20
	leanSpring.peekFactor = math_rad(-15)
	leanSpring.dirPeek = 0

	--// Controllers

	local crosshairController = CrosshairController.new(plr)
	local cameraController = CameraController.new(plr, cam, char, humanoid, rootPart, torso, acsClient)
	local castController = CastController.new(plr, cam, char, effectsFolder, Events, authToken, gameRules, destroyLater)
	local equipController = EquipController.new(plr, cam, char, humanoid, Events, GunModels, ArmModel, AttModels, AttModules, AttachmentModifiers.createDefault(), crosshairController, cameraController, castController)
	local inputController = InputController.new(plr, mouse)

	local cleanupCharacter: (() -> ())?

	--// Mutable Runtime State (shared by input handlers, combat actions, render loop)

	local state = {
		charspeed = 0,
		running = false,
		runKeyDown = false,
		aiming = false,
		shooting = false,
		reloading = false,
		mouse1down = false,
		animDebounce = false,
		cancelReload = false,
		safeMode = false,
		jumpDelay = false,
		nvg = false,
		gunStance = 0,
		stances = 0,
		virar = 0,
		cameraX = 0,
		cameraY = 0,
		sentado = false,
		swimming = false,
		steady = false,
		changeStance = true,
		tracers = 0,
		halfStep = false,
	}

	--// CFrames passed to RenderController

	local renderCF = {
		gunbobcf = CFrame_new(),
		recoilcf = CFrame_new(),
		aimcf = CFrame_new(),
		maincf = CFrame_new(),
		bipodCF = CFrame_new(),
		nearZ = CFrame_new(0, 0, -0.5),
	}

	local aimTween = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, false, 0)

	--// Render Controller

	local renderCtx: RenderController.RenderContext = {
		cameraController = cameraController,
		equipController = equipController,
		featureFlags = FeatureFlags,
		runtime = Runtime,
		gameRules = gameRules,
		events = Events,
		ignoreModel = ignoreModel,
		cameraSpring = cameraSpring,
		swaySpring = swaySpring,
		recoilSpring = recoilSpring,
		gunbobcf = renderCF.gunbobcf,
		recoilcf = renderCF.recoilcf,
		aimcf = renderCF.aimcf,
		maincf = renderCF.maincf,
		bipodCF = renderCF.bipodCF,
		nearZ = renderCF.nearZ,
		aimTween = aimTween,
		state = state,
		isThirdPersonCamera = function() return RuntimeSettings.GetBoolean("Third Person", true) end,
		updateCrosshair = function() crosshairController:update(equipController:getWeaponData(), equipController:isEquipped(), state.aiming, (equipController:getWeaponTool() and equipController:getWeaponTool().Name) or "") end,
	}
	local renderController = RenderController.new(cam, renderCtx)

	--// HUD

	local statusEffects = StatusEffectsGui.create(plr.PlayerGui, HUDs)
	local seGui = statusEffects.gui
	WeaponUIState.clear(plr)

	--// Helpers

	local function getWeaponName(): string
		local tool = equipController:getWeaponTool()
		return string_lower((tool and tool.Name) or "")
	end

	local function isThirdPersonCamera(): boolean
		return RuntimeSettings.GetBoolean("Third Person", true)
	end

	local function isShotgunWeapon(): boolean
		local weaponData = equipController:getWeaponData()
		if not weaponData then return false end
		if weaponData.WeaponType == "Shotgun" or weaponData.Shotgun == true then return true end
		local name = getWeaponName()
		return string_find(name, "shotgun", 1, true) ~= nil
			or string_find(name, "spas", 1, true) ~= nil
			or string_find(name, "mossberg", 1, true) ~= nil
	end

	local function isSniperWeapon(): boolean
		local weaponData = equipController:getWeaponData()
		if not weaponData then return false end
		local name = getWeaponName()
		if weaponData.Sniper == true or weaponData.WeaponType == "Sniper" then return true end
		if string_find(name, "sniper", 1, true)
			or string_find(name, "barrett", 1, true)
			or string_find(name, "awm", 1, true)
			or string_find(name, "m82", 1, true)
			or string_find(name, "kar98", 1, true) then return true end
		return typeof(weaponData.Zoom) == "number" and weaponData.Zoom <= 25 and not isShotgunWeapon()
	end

	local function applyWeaponCameraMode()
		if isThirdPersonCamera() then
			plr.CameraMode = Enum.CameraMode.Classic
		else
			plr.CameraMode = Enum.CameraMode.LockFirstPerson
		end
	end

	local function updateGui()
		local weaponData = equipController:getWeaponData()
		if weaponData then
			WeaponUIState.publishHud(plr, weaponData, equipController:getAmmo(), equipController:getStoredAmmo(), state.safeMode)
			crosshairController:update(weaponData, equipController:isEquipped(), state.aiming, (equipController:getWeaponTool() and equipController:getWeaponTool().Name) or "")
			WeaponHudAdapter.update(seGui, weaponData, equipController:getAmmo(), equipController:getStoredAmmo(), state.safeMode, equipController:getSuppressor(), equipController:getBipodAtt(), equipController:getSens())
		end
	end

	local function getStanceContext()
		return {
			humanoid = humanoid,
			characterModel = hostScript.Parent,
			gameRules = gameRules,
		}
	end

	local function tweenStanceCameraOffset()
		if RuntimeSettings.GetBoolean("CameraControllerOwnsOffset", false) then return end
		TweenService:Create(humanoid, TweenInfo.new(0.3), {
			CameraOffset = Vector3.new(state.cameraX, state.cameraY, humanoid.CameraOffset.Z),
		}):Play()
	end

	local function playWeaponAnimation(animationName: string): boolean
		local animController = equipController:getAnimationController()
		if not animController then return false end
		return animController:play(animationName)
	end

	--// Stance helpers

	local function runCheck()
		if state.runKeyDown then
			state.mouse1down = false
			state.gunStance = 3
			Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
			playWeaponAnimation("SprintAnim")
		else
			state.gunStance = if state.aiming then 2 else 0
			Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
			playWeaponAnimation("IdleAnim")
		end
	end

	--// Stance actions

	local function stand()
		Events.Stance:FireServer(state.stances, state.virar)
		tweenStanceCameraOffset()
		StanceController.applyStand(getStanceContext(), state.steady)
	end

	local function crouch()
		Events.Stance:FireServer(state.stances, state.virar)
		tweenStanceCameraOffset()
		StanceController.applyCrouch(getStanceContext())
	end

	--// Combat actions

	local function gunFx()
		local weaponData = equipController:getWeaponData()
		local weaponInHand = equipController:getWeaponInHand()
		local nextState = FireEffectsController.apply(
			weaponInHand, weaponData, equipController:getModTable(),
			equipController:getAmmo(),
			equipController:getSuppressor(), equipController:getFlashHider(), {
				bSpread = equipController:getBSpread(),
				recoilPower = equipController:getRecoilPower(),
				generateBullet = equipController:getGenerateBullet(),
				lastSpreadUpdate = equipController:getLastSpreadUpdate(),
			})
		equipController:setBSpread(nextState.bSpread)
		equipController:setRecoilPower(nextState.recoilPower)
		equipController:setGenerateBullet(nextState.generateBullet)
		equipController:setLastSpreadUpdate(nextState.lastSpreadUpdate)
	end

	local function applyRecoil()
		local weaponAnimator = equipController:getWeaponAnimator()
		if weaponAnimator then
			weaponAnimator:Fire(equipController:getRecoilPower())
		end

		renderController:setRecoilCF(RecoilController.apply({
			WeaponData = equipController:getWeaponData(),
			ModTable = equipController:getModTable(),
			BipodActive = equipController:getBipodActive(),
			Aiming = state.aiming,
			RecoilPower = equipController:getRecoilPower(),
			CameraSpring = cameraSpring,
			RecoilSpring = recoilSpring,
			RecoilCFrame = renderController:getRecoilCF(),
			RandomRange = function(min, max, accuracy) return Runtime.randomRange(min, max, accuracy) end,
			Schedule = function(duration, cb) schedule(duration, cb, "ACS:RecoilRecover") end,
		}))
	end

	local function fireRound()
		local weaponData = equipController:getWeaponData()
		if not weaponData then return end

		Events.Atirar:FireServer(equipController:getWeaponTool(), equipController:getSuppressor(), equipController:getFlashHider())

		for _ = 1, weaponData.Bullets do
			Thread:Spawn(function()
				castController:createBullet(
					equipController:getBSpread(),
					state.charspeed,
					state.aiming,
					not isThirdPersonCamera()
				)
			end)
		end

		local ammo = equipController:getAmmo() - 1
		equipController:setAmmo(ammo)
		gunFx()

		if weaponData.Jammed == nil then
			weaponData.Jammed = false
		end
		if JamController.roll(weaponData, { ammo = ammo }, math_random) then
			local weaponInHand = equipController:getWeaponInHand()
			if weaponInHand and weaponInHand.Handle:FindFirstChild("Click") then
				weaponInHand.Handle.Click:Play()
			end
		end

		updateGui()
		Thread:Spawn(applyRecoil)
	end

	local function reload()
		local weaponData = equipController:getWeaponData()
		local ammo = equipController:getAmmo()
		local storedAmmo = equipController:getStoredAmmo()

		if not ReloadController.canReload(weaponData, { ammo = ammo, storedAmmo = storedAmmo }) then return end

		state.mouse1down = false
		state.reloading = true
		state.safeMode = false
		state.gunStance = 0
		Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
		updateGui()

		if weaponData.ShellInsert then
			if ammo > 0 then
				for _ = 1, weaponData.Ammo - ammo do
					if storedAmmo <= 0 or ammo >= weaponData.Ammo or state.cancelReload then break end
					playWeaponAnimation("ReloadAnim")
					local nextA = ReloadController.insertOne({ ammo = ammo, storedAmmo = storedAmmo })
					ammo = nextA.ammo; storedAmmo = nextA.storedAmmo
					equipController:setAmmo(ammo); equipController:setStoredAmmo(storedAmmo)
					updateGui()
				end
			else
				playWeaponAnimation("TacticalReloadAnim")
				local nextA = ReloadController.insertOne({ ammo = ammo, storedAmmo = storedAmmo })
				ammo = nextA.ammo; storedAmmo = nextA.storedAmmo
				equipController:setAmmo(ammo); equipController:setStoredAmmo(storedAmmo)
				updateGui()
				for _ = 1, weaponData.Ammo - ammo do
					if storedAmmo <= 0 or ammo >= weaponData.Ammo or state.cancelReload then break end
					playWeaponAnimation("ReloadAnim")
					local nextA = ReloadController.insertOne({ ammo = ammo, storedAmmo = storedAmmo })
					ammo = nextA.ammo; storedAmmo = nextA.storedAmmo
					equipController:setAmmo(ammo); equipController:setStoredAmmo(storedAmmo)
					updateGui()
				end
			end
		else
			if ammo > 0 then playWeaponAnimation("ReloadAnim")
			else playWeaponAnimation("TacticalReloadAnim") end
			local nextA = ReloadController.finishMagazineReload(weaponData, { ammo = ammo, storedAmmo = storedAmmo })
			ammo = nextA.ammo; storedAmmo = nextA.storedAmmo
			equipController:setAmmo(ammo); equipController:setStoredAmmo(storedAmmo)
		end

		state.cancelReload = false
		state.reloading = false
		runCheck()
		updateGui()
	end

	local function jammed()
		local weaponData = equipController:getWeaponData()
		if not JamController.canClear(weaponData) then return end
		state.mouse1down = false
		state.reloading = true
		state.safeMode = false
		state.gunStance = 0
		Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
		updateGui()
		playWeaponAnimation("JammedAnim")
		weaponData.Jammed = false
		updateGui()
		state.reloading = false
		runCheck()
	end

	local function shoot()
		local weaponData = equipController:getWeaponData()

		local shotState = {
			ammo = equipController:getAmmo(),
			shooting = state.shooting,
			reloading = state.reloading,
			runKeyDown = state.runKeyDown,
			safeMode = state.safeMode,
			checkingMag = equipController:getCheckingMag(),
			mouseDown = state.mouse1down,
		}

		local function setShooting(v) state.shooting = v; shotState.shooting = v end
		local function setMouseDown(v) state.mouse1down = v; shotState.mouseDown = v end

		ShootingController.shoot(weaponData, shotState, {
			setShooting = setShooting,
			setMouseDown = setMouseDown,
			isMouseDown = function() return state.mouse1down end,
			fireRound = fireRound,
			firePumpRound = function()
				if not weaponData then return end
				Events.Atirar:FireServer(equipController:getWeaponTool(), equipController:getSuppressor(), equipController:getFlashHider())
				for _ = 1, weaponData.Bullets do
					Thread:Spawn(function()
						castController:createBullet(equipController:getBSpread(), state.charspeed, state.aiming, not isThirdPersonCamera())
					end)
				end
				local ammo = equipController:getAmmo() - 1
				equipController:setAmmo(ammo)
				gunFx()
				updateGui()
				Thread:Spawn(applyRecoil)
			end,
			playEmptyClick = function()
				local w = equipController:getWeaponInHand()
				if w and w.Handle:FindFirstChild("Click") then w.Handle.Click:Play() end
			end,
			pump = function()
				state.reloading = true
				playWeaponAnimation("PumpAnim")
				state.reloading = false
			end,
			runCheck = runCheck,
			melee = function()
				-- Melee cast delegates to CastController
				castController:meleeCast()
				playWeaponAnimation("meleeAttack")
			end,
			schedule = schedule,
		})
	end

	local function enterThirdPersonCombatFocus()
		if not isThirdPersonCamera() then return end
		local weaponData = equipController:getWeaponData()
		if state.aiming or not weaponData or not weaponData.canAim or state.gunStance <= -2 or state.runKeyDown or equipController:getCheckingMag() then return end
		state.aiming = true
		WeaponUIState.setAiming(plr, true)
		if state.safeMode then
			state.safeMode = false; state.gunStance = 0
			playWeaponAnimation("IdleAnim"); updateGui()
		end
		UserInputService.MouseDeltaSensitivity = equipController:getSens() / 100
		local wih = equipController:getWeaponInHand()
		if wih and wih.Handle:FindFirstChild("AimDown") then wih.Handle.AimDown:Play() end
		state.gunStance = 2
		Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
		crosshairController:update(equipController:getWeaponData(), equipController:isEquipped(), state.aiming, (equipController:getWeaponTool() and equipController:getWeaponTool().Name) or "")
	end

	--// Input Dispatch Table (replaces ~25-branch elseif chain)

	local actionHandlers: { [string]: (string, Enum.UserInputState, any) -> () } = {}

	function actionHandlers.Fire(actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin and state.animDebounce then
			enterThirdPersonCombatFocus()
			shoot()
		elseif inputState == Enum.UserInputState.End then
			state.mouse1down = false
		end
	end

	function actionHandlers.Reload(actionName, inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin then return end
		if state.animDebounce and not equipController:getCheckingMag() and not state.reloading then
			local weaponData = equipController:getWeaponData()
			if weaponData and weaponData.Jammed then jammed() else reload() end
		elseif state.reloading then
			local weaponData = equipController:getWeaponData()
			if weaponData and weaponData.ShellInsert then state.cancelReload = true end
		end
	end

	function actionHandlers.CycleFiremode(actionName, inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin then return end
		local weaponData = equipController:getWeaponData()
		if weaponData and weaponData.FireModes and weaponData.FireModes.ChangeFiremode then
			state.mouse1down = false
			local wih = equipController:getWeaponInHand()
			if wih and wih.Handle:FindFirstChild("SafetyClick") then wih.Handle.SafetyClick:Play() end
			FiremodeController.cycle(weaponData); updateGui()
		end
	end

	function actionHandlers.ADS(actionName, inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin or not state.animDebounce then return end
		local weaponData = equipController:getWeaponData()
		if not weaponData or not weaponData.canAim or state.gunStance <= -2 or state.runKeyDown or equipController:getCheckingMag() then return end
		state.aiming = not state.aiming
		if not weaponData or not equipController:getWeaponInHand() then return end
		WeaponUIState.setAiming(plr, state.aiming)
		if state.aiming then
			if state.safeMode then state.safeMode = false; state.gunStance = 0; playWeaponAnimation("IdleAnim"); updateGui() end
			UserInputService.MouseDeltaSensitivity = equipController:getSens() / 100
			local wih = equipController:getWeaponInHand()
			if wih and wih.Handle:FindFirstChild("AimDown") then wih.Handle.AimDown:Play() end
			state.gunStance = 2
			Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
		else
			UserInputService.MouseDeltaSensitivity = 1
			local wih = equipController:getWeaponInHand()
			if wih and wih.Handle:FindFirstChild("AimUp") then wih.Handle.AimUp:Play() end
			state.gunStance = 0
			Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
		end
		crosshairController:update(equipController:getWeaponData(), equipController:isEquipped(), state.aiming, (equipController:getWeaponTool() and equipController:getWeaponTool().Name) or "")
	end

	function actionHandlers.Stand(actionName, inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin or not state.changeStance or state.swimming or state.sentado or state.runKeyDown or acsClient:GetAttribute("Collapsed") then return end
		if state.stances == 2 then state.stances = 1; state.cameraY = -1; crouch()
		elseif state.stances == 1 then state.stances = 0; state.cameraY = 0; stand() end
	end

	function actionHandlers.Crouch(actionName, inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin or not state.changeStance or state.swimming or state.sentado or state.runKeyDown or acsClient:GetAttribute("Collapsed") then return end
		if state.stances == 0 then state.stances = 1; state.cameraY = -1; crouch()
		elseif state.stances == 1 then state.stances = 2; state.cameraX = 0; state.cameraY = -3.25; state.virar = 0 end
	end

	function actionHandlers.ToggleWalk(actionName, inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin or not state.changeStance or state.runKeyDown then return end
		state.steady = not state.steady
		if state.stances == 0 then stand() end
	end

	function actionHandlers.Run(actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin and state.running and not hostScript.Parent:GetAttribute("Injured") then
			state.mouse1down = false; state.runKeyDown = true
			stand(); state.stances = 0; state.virar = 0; state.cameraX = 0; state.cameraY = 0
			humanoid.WalkSpeed = gameRules.RunWalkSpeed
			if state.aiming then
				state.aiming = false; WeaponUIState.setAiming(plr, false)
				UserInputService.MouseDeltaSensitivity = 1
				local wih = equipController:getWeaponInHand()
				if wih and wih.Handle:FindFirstChild("AimUp") then wih.Handle.AimUp:Play() end
				state.gunStance = 0
				Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
				crosshairController:update(equipController:getWeaponData(), equipController:isEquipped(), state.aiming, (equipController:getWeaponTool() and equipController:getWeaponTool().Name) or "")
			end
			if not equipController:getCheckingMag() and not state.reloading then
				local weaponData = equipController:getWeaponData()
				if weaponData and weaponData.Type ~= "Grenade" and (state.gunStance == 0 or state.gunStance == 2 or state.gunStance == 3) then
					state.gunStance = 3
					Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
					playWeaponAnimation("SprintAnim")
				end
			end
		elseif inputState == Enum.UserInputState.End and state.runKeyDown then
			state.runKeyDown = false; stand()
			if not equipController:getCheckingMag() and not state.reloading then
				local weaponData = equipController:getWeaponData()
				if weaponData and weaponData.Type ~= "Grenade" and (state.gunStance == 0 or state.gunStance == 2 or state.gunStance == 3) then
					state.gunStance = 0
					Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
					playWeaponAnimation("IdleAnim")
				end
			end
		end
	end

	function actionHandlers.WheelBackward(actionName, inputState, _inputObject)
		local toolEquip = equipController:isEquipped()
		local weaponData = equipController:getWeaponData()
		if toolEquip and not equipController:getCheckingMag() and not state.aiming and not state.reloading and not state.runKeyDown and state.animDebounce and weaponData and weaponData.Type == "Gun" then
			state.mouse1down = false
			if state.gunStance == 0 then state.safeMode = true; state.gunStance = -1; updateGui(); Events.GunStance:FireServer(-1, equipController:getAnimData()); playWeaponAnimation("LowReady")
			elseif state.gunStance == -1 then state.safeMode = true; state.gunStance = -2; updateGui(); Events.GunStance:FireServer(-2, equipController:getAnimData()); playWeaponAnimation("Patrol")
			elseif state.gunStance == 1 then state.safeMode = false; state.gunStance = 0; updateGui(); Events.GunStance:FireServer(0, equipController:getAnimData()); playWeaponAnimation("IdleAnim") end
		end
		if toolEquip and state.aiming and equipController:getSens() > 5 then
			equipController:setSens(equipController:getSens() - 5); updateGui()
			UserInputService.MouseDeltaSensitivity = equipController:getSens() / 100
		end
	end

	function actionHandlers.WheelForward(actionName, inputState, _inputObject)
		local toolEquip = equipController:isEquipped()
		local weaponData = equipController:getWeaponData()
		if toolEquip and not equipController:getCheckingMag() and not state.aiming and not state.reloading and not state.runKeyDown and state.animDebounce and weaponData and weaponData.Type == "Gun" then
			state.mouse1down = false
			if state.gunStance == 0 then state.safeMode = true; state.gunStance = 1; updateGui(); Events.GunStance:FireServer(1, equipController:getAnimData()); playWeaponAnimation("HighReady")
			elseif state.gunStance == -1 then state.safeMode = false; state.gunStance = 0; updateGui(); Events.GunStance:FireServer(0, equipController:getAnimData()); playWeaponAnimation("IdleAnim")
			elseif state.gunStance == -2 then state.safeMode = true; state.gunStance = -1; updateGui(); Events.GunStance:FireServer(-1, equipController:getAnimData()); playWeaponAnimation("LowReady") end
		end
		if toolEquip and state.aiming and equipController:getSens() < 100 then
			equipController:setSens(equipController:getSens() + 5); updateGui()
			UserInputService.MouseDeltaSensitivity = equipController:getSens() / 100
		end
	end

	function actionHandlers.ToggleBipod(actionName, inputState, _inputObject)
		-- Bipod toggle is handled in the render loop; no-op here.
	end

	local function handleAction(actionName, inputState, inputObject)
		local handler = actionHandlers[actionName]
		if handler then
			handler(actionName, inputState, inputObject)
		end
	end

	--// Setup / Unset Weapon

	local function setup(tool)
		if not char or not tool or not humanoid or humanoid.Health <= 0 then return end
		local toolData = WeaponToolClassifier.readSettings(tool)
		if not WeaponToolClassifier.canEquip(toolData, FeatureFlags) then return end
		if humanoid.Sit and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then return end

		equipController:setup(tool)
		applyWeaponCameraMode()

		state.safeMode = false; state.gunStance = 0
		Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())

		inputController:bindWeaponActions(handleAction)
		if FeatureFlags.WeaponUtilitiesEnabled and equipController:getBipodAtt() then
			inputController:bindBipodToggle(handleAction)
		end

		UserInputService.MouseIconEnabled = false
		crosshairController:update(equipController:getWeaponData(), true, false, tool.Name)

		state.animDebounce = false
		playWeaponAnimation("EquipAnim")
		state.animDebounce = true

		task.delay(0.5, function()
			if equipController:isEquipped() and state.gunStance ~= 0 and state.gunStance ~= 2 then
				state.gunStance = 0
				Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
				playWeaponAnimation("IdleAnim")
				state.safeMode = false; updateGui()
			end
		end)

		local weaponData = equipController:getWeaponData()
		if weaponData and weaponData.Type ~= "Grenade" then runCheck() end
	end

	local function unset()
		equipController:unequip()
		inputController:unbindWeaponActions()
		if FeatureFlags.WeaponUtilitiesEnabled then inputController:unbindBipodToggle() end

		state.mouse1down = false; state.aiming = false; state.safeMode = false
		state.reloading = false; state.cancelReload = false; state.gunStance = 0
		state.animDebounce = false; state.shooting = false; state.tracers = 0

		TweenService:Create(cam, aimTween, { FieldOfView = 70 }):Play()
		WeaponUIState.clear(plr); crosshairController:clear()
		UserInputService.MouseIconEnabled = true; UserInputService.MouseDeltaSensitivity = 1
		cam.CameraType = Enum.CameraType.Custom; plr.CameraMode = Enum.CameraMode.Classic
		WeaponHudAdapter.setVisible(seGui, false); WeaponHudAdapter.hideGrenadeForce(seGui)
		renderController:reset()

		if gameRules.ReplicatedLaser then
			Events.SVLaser:FireServer(nil, 2, nil, false, equipController:getWeaponTool())
		end
	end

	--// Camera Lean Update

	connect(RunService:BindToRenderStep("Camera Update", 200, function()
		leanSpring.cornerPeek.t = leanSpring.peekFactor * state.virar
		local newLeanCF = CFrame.fromAxisAngle(Vector3.new(0, 0, 1), leanSpring.cornerPeek.p)
		cam.CFrame = cam.CFrame * newLeanCF
	end))

	--// Bind Default Movement Actions

	InputBindings.bindDefaultActions(ContextActionService, handleAction)

	--// Character Events

	connect(char.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") and humanoid.Health > 0 and not equipController:isEquipped() then
			setup(tool)
		end
	end))

	connect(char.ChildRemoved:Connect(function(tool)
		if tool == equipController:getWeaponTool() and equipController:isEquipped() then
			unset()
		end
	end))

	connect(humanoid.Running:Connect(function(speed)
		state.charspeed = speed
		state.running = speed > 0.1
	end))

	connect(humanoid.Died:Connect(function()
		TweenService:Create(humanoid, TweenInfo.new(1), { CameraOffset = Vector3.new(0, 0, 0) }):Play()
		state.changeStance = false; stand(); state.stances = 0
		state.virar = 0; state.cameraX = 0; state.cameraY = 0
		unset()
	end))

	connect(humanoid.Seated:Connect(function(isSeated, seat)
		if isSeated and seat and seat:IsA("VehicleSeat") then
			unset(); humanoid:UnequipTools()
			plr.CameraMaxZoomDistance = gameRules.VehicleMaxZoom
		else
			plr.CameraMaxZoomDistance = game.StarterPlayer.CameraMaxZoomDistance
		end
		state.sentado = isSeated
		if isSeated then state.stances = 0; state.virar = 0; state.cameraX = 0; state.cameraY = 0; stand() end
	end))

	connect(humanoid.Changed:Connect(function(prop)
		if not gameRules.AntiBunnyHop then return end
		if prop == "Jump" and humanoid.Sit == true and humanoid.SeatPart ~= nil then
			humanoid.Sit = false
		elseif prop == "Jump" and humanoid.Sit == false then
			if state.jumpDelay then humanoid.Jump = false; return false end
			state.jumpDelay = true
			schedule(gameRules.JumpCoolDown, function() state.jumpDelay = false end, "ACS:JumpCooldown")
		end
	end))

	connect(humanoid.StateChanged:Connect(function(_oldState, newState)
		if newState == Enum.HumanoidStateType.Swimming then
			state.swimming = true; state.stances = 0; state.virar = 0; state.cameraX = 0; state.cameraY = 0; stand()
		else state.swimming = false end
	end))

	connect(hostScript.Parent:GetAttributeChangedSignal("Injured"):Connect(function()
		local injured = hostScript.Parent:GetAttribute("Injured")
		if injured and state.runKeyDown then
			state.runKeyDown = false; stand()
			if not equipController:getCheckingMag() and not state.reloading then
				local weaponData = equipController:getWeaponData()
				if weaponData and weaponData.Type ~= "Grenade" and (state.gunStance == 0 or state.gunStance == 2 or state.gunStance == 3) then
					state.gunStance = 0
					Events.GunStance:FireServer(state.gunStance, equipController:getAnimData())
					playWeaponAnimation("IdleAnim")
				end
			end
		end
		if state.stances == 0 then stand() elseif state.stances == 1 then crouch() end
	end))

	connect(acsClient:GetAttributeChangedSignal("Collapsed"):Connect(function()
		if not acsClient:GetAttribute("Collapsed") then return end
		state.runKeyDown = true; stand(); state.stances = 0; state.virar = 0; state.cameraX = 0; state.cameraY = 0
	end))

	--// Settings Observer

	local settingsConn = RuntimeSettings.Observe("Third Person", function()
		if equipController:isEquipped() then applyWeaponCameraMode() end
	end)
	if settingsConn and settingsConn.Disconnect then connect(settingsConn) end

	--// Render Loop

	connect(RunService.RenderStepped:Connect(function(deltaTime)
		-- Camera head movement
		cameraController:headMovement(equipController:isEquipped(), state.aiming, equipController:getWeaponData(), acsClient)

		-- Viewmodel render pipeline (delegated to RenderController)
		renderController:step(deltaTime)
	end))

	--// Events

	connect(Events.Refil.OnClientEvent:Connect(function(tool, infinite, stored)
		local data = require(tool.ACS_Settings)
		local storedAmmo = equipController:getStoredAmmo()
		if infinite then
			local configuredReserve = if typeof(data.StoredAmmo) == "number" then data.StoredAmmo else storedAmmo
			local maxReserve = if typeof(data.MaxStoredAmmo) == "number" then data.MaxStoredAmmo else configuredReserve
			if maxReserve == math.huge then
				equipController:setStoredAmmo(math_max(storedAmmo, configuredReserve))
			else equipController:setStoredAmmo(maxReserve) end
			data.StoredAmmo = equipController:getStoredAmmo(); updateGui(); return
		end
		local newStored = math_min(data.MaxStoredAmmo - storedAmmo, stored.Value)
		equipController:setStoredAmmo(storedAmmo + newStored)
		data.StoredAmmo = equipController:getStoredAmmo(); updateGui()
		if not infinite then Events.Refil:FireServer(stored, newStored) end
	end))

	--// Lifecycle Cleanup

	cleanupCharacter = function()
		for _, conn in ipairs(connections) do conn:Disconnect() end
		table.clear(connections)
		RunService:UnbindFromRenderStep("Camera Update")
		InputBindings.unbindDefaultActions(ContextActionService)
	end

	connect(char.Destroying:Connect(function()
		if cleanupCharacter then cleanupCharacter() end
	end))
end

return Main
