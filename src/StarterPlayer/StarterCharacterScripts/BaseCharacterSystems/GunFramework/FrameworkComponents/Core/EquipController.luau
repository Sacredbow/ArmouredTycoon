--!strict
--[[
	@class EquipController

	@desc
	Owns the weapon equip/unequip lifecycle: model cloning, arm rigging,
	attachment loading, ammunition initialization, and ECS rig entity setup.
	All state is pushed into a mutable WeaponContext table that Main owns.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ContextActionService = game:GetService("ContextActionService")

--// Modules

const Runtime = require(script.Parent.Runtime)
const FeatureFlags = require(script.Parent.FeatureFlags)
const WeaponToolClassifier = require(script.Parent.WeaponToolClassifier)
const WeaponDefinitionResolver = require(ReplicatedStorage.Weapons.Resolver)
const AttachmentController = require(script.Parent.Parent.Combat.AttachmentController)
const AttachmentModifiers = require(script.Parent.Parent.Combat.AttachmentModifiers)
const WeaponAnimator = require(script.Parent.Parent.WeaponAnimation.WeaponAnimator)
const AnimationController = require(script.Parent.AnimationController)
const WeaponUIState = require(script.Parent.Parent.UI.WeaponUIState)
const WeaponHudAdapter = require(script.Parent.Parent.UI.WeaponHudAdapter)
const PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)
const Packets = PacketBootstrap.Get()

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const GunModels = Engine:WaitForChild("GunModels") :: any
const ArmModel = Engine:WaitForChild("ArmModel") :: any
const AttModels = Engine:WaitForChild("AttModels") :: any
const AttModules = Engine:WaitForChild("AttModules") :: any
const Mods = Engine:WaitForChild("Modules") :: any

local Utilities: any
local ok, utilModule = pcall(function()
	return require(Mods:WaitForChild("Utilities"))
end)
if ok then
	Utilities = utilModule
else
	Utilities = {
		Weld = function(part0: BasePart, part1: BasePart)
			local motor = Instance.new("Motor6D")
			motor.Name = part1.Name
			motor.Part0 = part0
			motor.Part1 = part1
			motor.C0 = CFrame.new()
			motor.C1 = part1.CFrame:ToObjectSpace(part0.CFrame)
			motor.Parent = part0
			return motor
		end,
		WeldComplex = function(part0: BasePart, part1: BasePart, name: string)
			local motor = Instance.new("Motor6D")
			motor.Name = name
			motor.Part0 = part0
			motor.Part1 = part1
			motor.C0 = CFrame.new()
			motor.C1 = part1.CFrame:ToObjectSpace(part0.CFrame)
			motor.Parent = part0
			return motor
		end,
	}
end

--// Constants

const AIM_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

local function cloneSettings(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, child in value do
		copy[key] = cloneSettings(child)
	end
	return copy
end

local EquipController = {}
EquipController.__index = EquipController

export type EquipController = typeof(setmetatable({} :: {
	_player: Player,
	_camera: Camera,
	_character: Model,
	_humanoid: Humanoid,
	_gunModels: any,
	_armModel: any,
	_attModels: any,
	_attModules: any,
	_modTable: any,
	_animationController: AnimationController.AnimationController?,
	_weaponAnimator: any?,
	_crosshairController: any?,
	_cameraController: any?,
	_castController: any?,
	_state: any,
	_viewModel: Model?,
	_weaponInHand: Model?,
	_weaponTool: Tool?,
	_weaponData: any,
	_animData: any,
	_ammo: number,
	_storedAmmo: number,
	_jammed: boolean,
	_shootType: number,
	_bSpread: number,
	_recoilPower: number,
	_lastSpreadUpdate: number,
	_generateBullet: number,
	_aimPartMode: number,
	_curAimpart: BasePart?,
	_suppressor: boolean,
	_flashHider: boolean,
	_underBarrelAtt: Model?,
	_laserActive: boolean,
	_irMode: boolean,
	_irEnable: boolean,
	_pointer: Part?,
	_bipodAtt: boolean,
	_canBipod: boolean,
	_bipodActive: boolean,
	_grDebounce: boolean,
	_checkingMag: boolean,
	_toolEquip: boolean,
	_sens: number,
	_power: number,
	_bipodCF: CFrame,
	_nearZ: CFrame,
	_mainCF: CFrame,
	_gunCF: CFrame,
	_gunBobCF: CFrame,
	_recoilCF: CFrame,
	_aimCF: CFrame,
	_viewModelEnabledStates: { [Instance]: boolean },
	_viewModelTransparencyStates: { [Instance]: number },
}, EquipController))

function EquipController.new(
	player: Player,
	camera: Camera,
	character: Model,
	humanoid: Humanoid,
	gunModels: any,
	armModel: any,
	attModels: any,
	attModules: any,
	modTable: any,
	crosshairController: any,
	cameraController: any,
	castController: any
): EquipController
	return setmetatable({
		_player = player,
		_camera = camera,
		_character = character,
		_humanoid = humanoid,
		_gunModels = gunModels,
		_armModel = armModel,
		_attModels = attModels,
		_attModules = attModules,
		_modTable = modTable,
		_animationController = nil,
		_weaponAnimator = nil,
		_crosshairController = crosshairController,
		_cameraController = cameraController,
		_castController = castController,
		_state = nil,
		_viewModel = nil,
		_weaponInHand = nil,
		_weaponTool = nil,
		_weaponData = nil,
		_animData = nil,
		_ammo = 0,
		_storedAmmo = 0,
		_jammed = false,
		_shootType = 1,
		_bSpread = 0,
		_recoilPower = 0,
		_lastSpreadUpdate = 0,
		_generateBullet = 1,
		_aimPartMode = 1,
		_curAimpart = nil,
		_suppressor = false,
		_flashHider = false,
		_underBarrelAtt = nil,
		_laserActive = false,
		_irMode = false,
		_irEnable = false,
		_pointer = nil,
		_bipodAtt = false,
		_canBipod = false,
		_bipodActive = false,
		_grDebounce = false,
		_checkingMag = false,
		_toolEquip = false,
		_sens = 50,
		_power = 150,
		_bipodCF = CFrame.new(),
		_nearZ = CFrame.new(0, 0, -0.5),
		_mainCF = CFrame.new(),
		_gunCF = CFrame.new(),
		_gunBobCF = CFrame.new(),
		_recoilCF = CFrame.new(),
		_aimCF = CFrame.new(),
		_viewModelEnabledStates = {},
		_viewModelTransparencyStates = {},
	}, EquipController)
end

--// Getters (for Main to read state)

function EquipController:setCamera(camera: Camera)
	self._camera = camera
	if self._viewModel then
		self._viewModel.Parent = camera
	end
end

function EquipController:isEquipped(): boolean return self._toolEquip end
function EquipController:getWeaponTool(): Tool? return self._weaponTool end
function EquipController:getWeaponData(): any return self._weaponData end
function EquipController:getAnimData(): any return self._animData end
function EquipController:getViewModel(): Model? return self._viewModel end
function EquipController:getWeaponInHand(): Model? return self._weaponInHand end
function EquipController:getAmmo(): number return self._ammo end
function EquipController:getStoredAmmo(): number return self._storedAmmo end
function EquipController:getJammed(): boolean return self._jammed end
function EquipController:getShootType(): number return self._shootType end
function EquipController:getBSpread(): number return self._bSpread end
function EquipController:getRecoilPower(): number return self._recoilPower end
function EquipController:getLastSpreadUpdate(): number return self._lastSpreadUpdate end
function EquipController:getGenerateBullet(): number return self._generateBullet end
function EquipController:getAimPartMode(): number return self._aimPartMode end
function EquipController:getCurAimpart(): BasePart? return self._curAimpart end
function EquipController:getSuppressor(): boolean return self._suppressor end
function EquipController:getFlashHider(): boolean return self._flashHider end
function EquipController:getUnderBarrelAtt(): Model? return self._underBarrelAtt end
function EquipController:getLaserActive(): boolean return self._laserActive end
function EquipController:getIRMode(): boolean return self._irMode end
function EquipController:getIREnable(): boolean return self._irEnable end
function EquipController:getPointer(): Part? return self._pointer end
function EquipController:getBipodAtt(): boolean return self._bipodAtt end
function EquipController:getCanBipod(): boolean return self._canBipod end
function EquipController:getBipodActive(): boolean return self._bipodActive end
function EquipController:getGRDebounce(): boolean return self._grDebounce end
function EquipController:getCheckingMag(): boolean return self._checkingMag end
function EquipController:getSens(): number return self._sens end
function EquipController:getPower(): number return self._power end
function EquipController:getBipodCF(): CFrame return self._bipodCF end
function EquipController:getNearZ(): CFrame return self._nearZ end
function EquipController:getMainCF(): CFrame return self._mainCF end
function EquipController:getGunCF(): CFrame return self._gunCF end
function EquipController:getGunBobCF(): CFrame return self._gunBobCF end
function EquipController:getRecoilCF(): CFrame return self._recoilCF end
function EquipController:getAimCF(): CFrame return self._aimCF end
function EquipController:getAnimationController(): AnimationController.AnimationController? return self._animationController end
function EquipController:getWeaponAnimator(): any? return self._weaponAnimator end
function EquipController:getModTable(): any return self._modTable end

--// Setters (for Main to mutate state)

function EquipController:setAmmo(value: number) self._ammo = value end
function EquipController:setStoredAmmo(value: number) self._storedAmmo = value end
function EquipController:setJammed(value: boolean) self._jammed = value end
function EquipController:setShootType(value: number) self._shootType = value end
function EquipController:setBSpread(value: number) self._bSpread = value end
function EquipController:setRecoilPower(value: number) self._recoilPower = value end
function EquipController:setLastSpreadUpdate(value: number) self._lastSpreadUpdate = value end
function EquipController:setGenerateBullet(value: number) self._generateBullet = value end
function EquipController:setAimPartMode(value: number) self._aimPartMode = value end
function EquipController:setCurAimpart(part: BasePart?) self._curAimpart = part end
function EquipController:setSuppressor(value: boolean) self._suppressor = value end
function EquipController:setFlashHider(value: boolean) self._flashHider = value end
function EquipController:setUnderBarrelAtt(model: Model?) self._underBarrelAtt = model end
function EquipController:setLaserActive(value: boolean) self._laserActive = value end
function EquipController:setIRMode(value: boolean) self._irMode = value end
function EquipController:setIREnable(value: boolean) self._irEnable = value end
function EquipController:setPointer(part: Part?) self._pointer = part end
function EquipController:setBipodAtt(value: boolean) self._bipodAtt = value end
function EquipController:setCanBipod(value: boolean) self._canBipod = value end
function EquipController:setBipodActive(value: boolean) self._bipodActive = value end
function EquipController:setGRDebounce(value: boolean) self._grDebounce = value end
function EquipController:setCheckingMag(value: boolean) self._checkingMag = value end
function EquipController:setSens(value: number) self._sens = value end
function EquipController:setPower(value: number) self._power = value end
function EquipController:setBipodCF(cf: CFrame) self._bipodCF = cf end
function EquipController:setMainCF(cf: CFrame) self._mainCF = cf end
function EquipController:setGunCF(cf: CFrame) self._gunCF = cf end
function EquipController:setGunBobCF(cf: CFrame) self._gunBobCF = cf end
function EquipController:setRecoilCF(cf: CFrame) self._recoilCF = cf end
function EquipController:setAimCF(cf: CFrame) self._aimCF = cf end

--// Public API

function EquipController:resetMods()
	AttachmentController.resetModifiers(self._modTable)
end

function EquipController:loadAttachment(weapon: any)
	local attachments = AttachmentController.load(weapon, self._weaponData, self._modTable, self._attModels, self._attModules, Utilities)

	self._underBarrelAtt = attachments.underBarrel
	self._suppressor = attachments.suppressor
	self._flashHider = attachments.flashHider
	self._irEnable = self._irEnable or attachments.infrared
	self._bipodAtt = attachments.bipod
end


function EquipController:setup(tool: Tool): boolean
	if self._toolEquip then
		return false
	end
	if not self._character or not tool then
		return false
	end

	local humanoid = self._character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	const weaponId = WeaponDefinitionResolver.getId(tool) or tool.Name
	const gunModelCheck = self._gunModels:FindFirstChild(weaponId)
	if not gunModelCheck or not gunModelCheck:IsA("Model") then
		warn(("[ACS] Gun model does not exist for weapon %s"):format(weaponId))
		return false
	end

	const settingsModule = WeaponDefinitionResolver.getSettings(tool)
	const animationsModule = WeaponDefinitionResolver.getAnimations(tool)

	if not settingsModule or not settingsModule:IsA("ModuleScript")
		or not animationsModule or not animationsModule:IsA("ModuleScript") then
		warn(("[ACS] %s is missing authored settings or animations"):format(tool.Name))
		return false
	end

	local settingsOk, loadedSettings = pcall(require, settingsModule)
	local animationsOk, loadedAnimations = pcall(require, animationsModule)
	if not settingsOk or type(loadedSettings) ~= "table"
		or not animationsOk or type(loadedAnimations) ~= "table"
		or typeof(loadedAnimations.MainCFrame) ~= "CFrame"
		or typeof(loadedAnimations.GunCFrame) ~= "CFrame" then
		warn(("[ACS] %s has invalid authored settings or animations"):format(tool.Name))
		return false
	end

	local weaponData = cloneSettings(loadedSettings)
	local modTable = AttachmentModifiers.createDefault()
	local weaponAnimator = WeaponAnimator.new(loadedAnimations)
	local weaponInHand: Model? = nil
	local viewModel: Model? = nil
	local animationController: AnimationController.AnimationController? = nil
	local underBarrelAtt: Model? = nil
	local suppressor = false
	local flashHider = false
	local irEnable = weaponData.InfraRed == true
	local bipodAtt = false
	local bSpread = 0
	local recoilPower = 0
	local ammo = 0
	local storedAmmo = 0
	local curAimpart: BasePart? = nil

	local success, errorMessage = xpcall(function()
		weaponInHand = gunModelCheck:Clone()
		local handle = weaponInHand and weaponInHand:FindFirstChild("Handle")
		if not handle or not handle:IsA("BasePart") then
			error("weapon model is missing a BasePart Handle")
		end
		weaponInHand.PrimaryPart = handle

		viewModel = self._armModel:WaitForChild("Arms"):Clone()
		viewModel.Name = "Viewmodel"

		local bodyColors = self._character:FindFirstChild("Body Colors")
		if bodyColors then
			bodyColors:Clone().Parent = viewModel
		end
		local shirt = self._character:FindFirstChild("Shirt")
		if shirt then
			shirt:Clone().Parent = viewModel
		end

		local animPart = Instance.new("Part")
		animPart.Name = "AnimPart"
		animPart.Size = Vector3.new(0.1, 0.1, 0.1)
		animPart.Anchored = true
		animPart.CanCollide = false
		animPart.Transparency = 1
		animPart.Parent = viewModel
		viewModel.PrimaryPart = animPart

		local laWeld = Instance.new("Motor6D")
		laWeld.Name = "LeftArm"
		laWeld.Part0 = animPart
		laWeld.Parent = animPart

		local raWeld = Instance.new("Motor6D")
		raWeld.Name = "RightArm"
		raWeld.Part0 = animPart
		raWeld.Parent = animPart

		local gunWeld = Instance.new("Motor6D")
		gunWeld.Name = "Handle"
		gunWeld.Part0 = animPart
		gunWeld.Parent = animPart

		local leftArm = viewModel:WaitForChild("Left Arm")
		local rightArm = viewModel:WaitForChild("Right Arm")
		if not leftArm:IsA("BasePart") or not rightArm:IsA("BasePart") then
			error("viewmodel arms are missing expected BaseParts")
		end

		laWeld.Part1 = leftArm
		laWeld.C0 = CFrame.new()
		laWeld.C1 = CFrame.new(1, -1, -5)
		raWeld.Part1 = rightArm
		raWeld.C0 = CFrame.new()
		raWeld.C1 = CFrame.new(-1, -1, -5)
		gunWeld.Part0 = rightArm
		leftArm.Anchored = false
		rightArm.Anchored = false
		local initialAmmo = if typeof(weaponData.AmmoInGun) == "number" then weaponData.AmmoInGun else 0
		local initialStoredAmmo = if typeof(weaponData.StoredAmmo) == "number" then weaponData.StoredAmmo else 0
		modTable.ZoomValue = if typeof(weaponData.Zoom) == "number" then weaponData.Zoom else modTable.ZoomValue
		modTable.Zoom2Value = if typeof(weaponData.Zoom2) == "number" then weaponData.Zoom2 else modTable.Zoom2Value

		local attachments = AttachmentController.load(
			weaponInHand,
			weaponData,
			modTable,
			self._attModels,
			self._attModules,
			Utilities
		)
		underBarrelAtt = attachments.underBarrel
		suppressor = attachments.suppressor
		flashHider = attachments.flashHider
		irEnable = irEnable or attachments.infrared
		bipodAtt = attachments.bipod

		for _, key in weaponInHand:GetChildren() do
			if key:IsA("BasePart") and key.Name ~= "Handle" then
				if key.Name ~= "Bolt" and key.Name ~= "Lid" and key.Name ~= "Slide" then
					Utilities.Weld(handle, key)
				elseif key.Name == "Bolt" or key.Name == "Slide" then
					Utilities.WeldComplex(handle, key, key.Name)
				elseif key.Name == "Lid" then
					local hinge = weaponInHand:FindFirstChild("LidHinge")
					if hinge and hinge:IsA("BasePart") then
						Utilities.Weld(key, hinge)
					else
						Utilities.Weld(key, handle)
					end
				end
			end
		end

		for _, child in weaponInHand:GetChildren() do
			if child:IsA("BasePart") then
				child.Anchored = false
				child.CanCollide = false
			end
		end

		local nodes = weaponInHand:FindFirstChild("Nodes")
		if nodes then
			for _, node in nodes:GetChildren() do
				if node:IsA("BasePart") then
					Utilities.Weld(handle, node)
					node.Anchored = false
					node.CanCollide = false
				end
			end
		end

		gunWeld.Part1 = handle
		gunWeld.C1 = loadedAnimations.GunCFrame
		weaponInHand.Parent = viewModel

		local slide = handle:FindFirstChild("Slide")
		if initialAmmo <= 0 and weaponData.Type == "Gun"
			and slide and slide:IsA("Motor6D") and typeof(weaponData.SlideEx) == "CFrame" then
			slide.C0 = weaponData.SlideEx:Inverse()
		end

		animationController = AnimationController.new(
			loadedAnimations,
			raWeld,
			laWeld,
			gunWeld,
			weaponInHand,
			viewModel
		)
		bSpread = math.min(weaponData.MinSpread * modTable.MinSpread, weaponData.MaxSpread * modTable.MaxSpread)
		recoilPower = math.min(weaponData.MinRecoilPower * modTable.MinRecoilPower, weaponData.MaxRecoilPower * modTable.MaxRecoilPower)
		ammo = initialAmmo
		storedAmmo = initialStoredAmmo
		local aimPart = weaponInHand:FindFirstChild("AimPart")
		curAimpart = if aimPart and aimPart:IsA("BasePart") then aimPart else nil
	end, debug.traceback)

	if not success then
		if viewModel then
			viewModel:Destroy()
		elseif weaponInHand then
			weaponInHand:Destroy()
		end
		warn(("[ACS] Equip failed for %s: %s"):format(tool.Name, tostring(errorMessage)))
		return false
	end

	self._modTable = modTable
	self._weaponTool = tool
	self._weaponData = weaponData
	self._animData = loadedAnimations
	self._weaponAnimator = weaponAnimator
	self._weaponInHand = weaponInHand
	self._viewModel = viewModel
	self._animationController = animationController
	self._underBarrelAtt = underBarrelAtt
	self._suppressor = suppressor
	self._flashHider = flashHider
	self._irEnable = irEnable
	self._bipodAtt = bipodAtt
	self._bSpread = bSpread
	self._recoilPower = recoilPower
	self._ammo = ammo
	self._storedAmmo = storedAmmo
	self._jammed = weaponData.Jammed == true
	self._shootType = if typeof(weaponData.ShootType) == "number" then weaponData.ShootType else 1
	self._curAimpart = curAimpart
	self._mainCF = loadedAnimations.MainCFrame
	self._gunCF = loadedAnimations.GunCFrame
	self._gunBobCF = CFrame.new()
	self._viewModelEnabledStates = {}
	self._viewModelTransparencyStates = {}

	viewModel.Parent = self._camera
	self._cameraController:setViewModel(viewModel)
	self._castController:setWeaponState(tool, weaponData, modTable, weaponInHand)
	WeaponUIState.setAiming(self._player, false)
	WeaponHudAdapter.setVisible(nil, weaponData.EnableHUD == true)
	self:updateGui()
	self._cameraController:applyCameraMode()
	self._toolEquip = true
	Packets.packets.EquipIntent.send({ weapon = tool, mode = 1 })
	return true
end

function EquipController:unequip()
	self._toolEquip = false
	WeaponUIState.setAiming(self._player, false)
	if self._weaponTool then
		Packets.packets.EquipIntent.send({ weapon = self._weaponTool, mode = 2 })
	end

	self._animationController = nil
	self._weaponAnimator = nil
	if self._viewModel then
		self._viewModel:Destroy()
	end

	self._viewModel = nil
	self._weaponInHand = nil
	self._weaponTool = nil
	self._weaponData = nil
	self._jammed = false
	self._shootType = 1
	self._animData = nil
	self._underBarrelAtt = nil
	self._laserActive = false
	self._irMode = false
	self._bipodAtt = false
	self._bipodActive = false
	self._pointer = nil
	self._bSpread = 0
	self._recoilPower = 0
	self._suppressor = false
	self._flashHider = false
	self._checkingMag = false
	self._grDebounce = false
	self._generateBullet = 1
	self._aimPartMode = 1

	self:resetMods()
	WeaponHudAdapter.setVisible(nil, false)
	WeaponHudAdapter.hideGrenadeForce(nil)
	self._bipodCF = CFrame.new()

	self._cameraController:setViewModel(nil)
	self._crosshairController:clear()

	self._castController:setWeaponState(nil, nil, nil, nil)
end

function EquipController:updateGui()
	if self._weaponData then
		WeaponUIState.publishHud(self._player, self._weaponData, self._ammo, self._storedAmmo, false, self._shootType, self._jammed)
		WeaponHudAdapter.update(nil, self._weaponData, self._ammo, self._storedAmmo, false, self._suppressor, self._bipodAtt, self._sens, self._shootType, self._jammed)
	end
end

function EquipController:grenadeMode()
	if self._power >= 150 then
		self._power = 100
		WeaponHudAdapter.setGrenadeForceText(nil, "Mid Throw")
	elseif self._power >= 100 then
		self._power = 50
		WeaponHudAdapter.setGrenadeForceText(nil, "Low Throw")
	elseif self._power >= 50 then
		self._power = 150
		WeaponHudAdapter.setGrenadeForceText(nil, "High Throw")
	end
end

return EquipController
