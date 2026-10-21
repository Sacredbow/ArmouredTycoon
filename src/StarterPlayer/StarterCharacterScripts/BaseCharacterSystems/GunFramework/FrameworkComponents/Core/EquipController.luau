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
const AttachmentController = require(script.Parent.Parent.Combat.AttachmentController)
const AttachmentModifiers = require(script.Parent.Parent.Combat.AttachmentModifiers)
const WeaponAnimator = require(script.Parent.Parent.WeaponAnimation.WeaponAnimator)
const AnimationController = require(script.Parent.AnimationController)
const WeaponUIState = require(script.Parent.Parent.UI.WeaponUIState)
const WeaponHudAdapter = require(script.Parent.Parent.UI.WeaponHudAdapter)

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const GunModels = Engine:WaitForChild("GunModels") :: any
const ArmModel = Engine:WaitForChild("ArmModel") :: any
const AttModels = Engine:WaitForChild("AttModels") :: any
const AttModules = Engine:WaitForChild("AttModules") :: any
const Events = Engine:WaitForChild("Events") :: any
const Mods = Engine:WaitForChild("Modules") :: any

local Ultil: any
local ok, utilModule = pcall(function()
	return require(Mods:WaitForChild("Utilities"))
end)
if ok then
	Ultil = utilModule
else
	Ultil = {
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

local EquipController = {}
EquipController.__index = EquipController

export type EquipController = typeof(setmetatable({} :: {
	_player: Player,
	_camera: Camera,
	_character: Model,
	_humanoid: Humanoid,
	_events: any,
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
	events: any,
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
		_events = events,
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

function EquipController:isEquipped(): boolean return self._toolEquip end
function EquipController:getWeaponTool(): Tool? return self._weaponTool end
function EquipController:getWeaponData(): any return self._weaponData end
function EquipController:getAnimData(): any return self._animData end
function EquipController:getViewModel(): Model? return self._viewModel end
function EquipController:getWeaponInHand(): Model? return self._weaponInHand end
function EquipController:getAmmo(): number return self._ammo end
function EquipController:getStoredAmmo(): number return self._storedAmmo end
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
	local attachments = AttachmentController.load(weapon, self._weaponData, self._modTable, self._attModels, self._attModules, Ultil)

	self._underBarrelAtt = attachments.underBarrel
	self._suppressor = attachments.suppressor
	self._flashHider = attachments.flashHider
	self._irEnable = self._irEnable or attachments.infrared
	self._bipodAtt = attachments.bipod
end

function EquipController:setup(tool: Tool)
	if not self._character or not tool then
		return
	end

	local humanoid = self._character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local gunModelCheck = self._gunModels:FindFirstChild(tool.Name)
	if not gunModelCheck then
		warn("Tool Or Gun Model Doesn't Exist")
		return
	end

	self._toolEquip = true
	WeaponUIState.setAiming(self._player, false)
	self._cameraController:applyCameraMode()

	self._weaponTool = tool
	self._weaponData = table.clone(require(tool:FindFirstChild("ACS_Settings")))
	self._animData = require(tool:FindFirstChild("ACS_Animations"))

	self._weaponAnimator = WeaponAnimator.new(self._animData)
	self._weaponInHand = gunModelCheck:Clone()
	self._weaponInHand.PrimaryPart = self._weaponInHand:WaitForChild("Handle")

	self._events.Equip:FireServer(tool, 1)

	-- Clone viewmodel arms
	self._viewModel = self._armModel:WaitForChild("Arms"):Clone()
	self._viewModel.Name = "Viewmodel"
	self._viewModelEnabledStates = {}
	self._viewModelTransparencyStates = {}

	if self._character:FindFirstChild("Body Colors") then
		local colors = self._character:FindFirstChild("Body Colors"):Clone()
		colors.Parent = self._viewModel
	end
	if self._character:FindFirstChild("Shirt") then
		local shirt = self._character:FindFirstChild("Shirt"):Clone()
		shirt.Parent = self._viewModel
	end

	-- AnimPart — invisible root that follows camera
	local animPart = Instance.new("Part")
	animPart.Parent = self._viewModel
	animPart.Size = Vector3.new(0.1, 0.1, 0.1)
	animPart.Anchored = true
	animPart.CanCollide = false
	animPart.Transparency = 1
	self._viewModel.PrimaryPart = animPart

	-- Arm welds
	local laWeld = Instance.new("Motor6D")
	laWeld.Parent = animPart
	laWeld.Name = "LeftArm"
	laWeld.Part0 = animPart

	local raWeld = Instance.new("Motor6D")
	raWeld.Parent = animPart
	raWeld.Name = "RightArm"
	raWeld.Part0 = animPart

	local gunWeld = Instance.new("Motor6D")
	gunWeld.Parent = animPart
	gunWeld.Name = "Handle"

	self._viewModel.Parent = self._camera
	self._mainCF = self._animData.MainCFrame
	self._gunCF = self._animData.GunCFrame
	self._gunBobCF = CFrame.new()

	-- Create animation controller
	self._animationController = AnimationController.new(self._animData, raWeld, laWeld, gunWeld, self._weaponInHand, self._viewModel)

	-- Wire up arms
	local la = self._viewModel:WaitForChild("Left Arm")
	laWeld.Part1 = la
	laWeld.C0 = CFrame.new()
	laWeld.C1 = CFrame.new(1, -1, -5) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)):inverse()

	local ra = self._viewModel:WaitForChild("Right Arm")
	raWeld.Part1 = ra
	raWeld.C0 = CFrame.new()
	raWeld.C1 = CFrame.new(-1, -1, -5) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)):inverse()

	gunWeld.Part0 = ra

	la.Anchored = false
	ra.Anchored = false

	-- Update camera state
	self._cameraController:setViewModel(self._viewModel)

	-- Attachment modifiers
	self._modTable.ZoomValue = self._weaponData.Zoom
	self._modTable.Zoom2Value = self._weaponData.Zoom2
	self._irEnable = self._weaponData.InfraRed
	self:loadAttachment(self._weaponInHand)

	-- Spread / recoil
	self._bSpread = math.min(self._weaponData.MinSpread * self._modTable.MinSpread, self._weaponData.MaxSpread * self._modTable.MaxSpread)
	self._recoilPower = math.min(self._weaponData.MinRecoilPower * self._modTable.MinRecoilPower, self._weaponData.MaxRecoilPower * self._modTable.MaxRecoilPower)

	self._ammo = self._weaponData.AmmoInGun
	self._storedAmmo = self._weaponData.StoredAmmo
	self._curAimpart = self._weaponInHand:FindFirstChild("AimPart")

	WeaponHudAdapter.setVisible(nil, self._weaponData.EnableHUD == true)
	self:updateGui()

	-- Weld weapon parts
	local handle = self._weaponInHand:WaitForChild("Handle") :: BasePart
	for _, key in self._weaponInHand:GetChildren() do
		if key:IsA("BasePart") and key.Name ~= "Handle" then
			if key.Name ~= "Bolt" and key.Name ~= "Lid" and key.Name ~= "Slide" then
				Ultil.Weld(handle, key)
			end
			if key.Name == "Bolt" or key.Name == "Slide" then
				Ultil.WeldComplex(handle, key, key.Name)
			end
			if key.Name == "Lid" then
				local hinge = self._weaponInHand:FindFirstChild("LidHinge")
				if hinge and hinge:IsA("BasePart") then
					Ultil.Weld(key, hinge)
				else
					Ultil.Weld(key, handle)
				end
			end
		end
	end

	for _, child in self._weaponInHand:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			child.CanCollide = false
		end
	end

	if self._weaponInHand:FindFirstChild("Nodes") then
		for _, node in self._weaponInHand.Nodes:GetChildren() do
			if node:IsA("BasePart") then
				Ultil.Weld(handle, node)
				node.Anchored = false
				node.CanCollide = false
			end
		end
	end

	gunWeld.Part1 = handle
	gunWeld.C1 = self._gunCF

	self._weaponInHand.Parent = self._viewModel

	if self._ammo <= 0 and self._weaponData.Type == "Gun" then
		local slide = handle:FindFirstChild("Slide")
		if slide and slide:IsA("Motor6D") and self._weaponData.SlideEx then
			slide.C0 = self._weaponData.SlideEx:inverse()
		end
	end

	-- Update cast controller state
	self._castController:setWeaponState(self._weaponTool, self._weaponData, self._modTable, self._weaponInHand)
end

function EquipController:unequip()
	self._toolEquip = false
	WeaponUIState.setAiming(self._player, false)
	self._events.Equip:FireServer(self._weaponTool, 2)

	self._animationController = nil
	self._weaponAnimator = nil

	-- Store ammo back to data
	if self._weaponData then
		self._weaponData.AmmoInGun = self._ammo
		self._weaponData.StoredAmmo = self._storedAmmo
	end

	if self._viewModel then
		self._viewModel:Destroy()
	end

	self._viewModel = nil
	self._weaponInHand = nil
	self._weaponTool = nil
	self._weaponData = nil
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
		self._weaponData.AmmoInGun = self._ammo
		self._weaponData.StoredAmmo = self._storedAmmo

		WeaponUIState.publishHud(self._player, self._weaponData, self._ammo, self._storedAmmo, false)
		self._crosshairController:update(self._weaponData, self._toolEquip, false, self._weaponTool and self._weaponTool.Name or "")
		WeaponHudAdapter.update(nil, self._weaponData, self._ammo, self._storedAmmo, false, self._suppressor, self._bipodAtt, self._sens)
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
