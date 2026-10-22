--!strict
--[[
	@class WeaponState

	@desc
	Type definitions for the mutable weapon runtime state shared across
	all ACS framework controller modules. Replaces the loose local variables
	in Main.luau with a typed, inspectable state object.
]]

export type WeaponAnimData = {
	MainCFrame: CFrame,
	GunCFrame: CFrame,
	LArmCFrame: CFrame?,
	RArmCFrame: CFrame?,
	SV_RightArmPos: CFrame,
	SV_LeftArmPos: CFrame,
	SV_GunPos: CFrame,
	GunModelFixed: boolean?,
	EquipAnim: ((any) -> ())?,
	IdleAnim: ((any) -> ())?,
	SprintAnim: ((any) -> ())?,
	ReloadAnim: ((any) -> ())?,
	TacticalReloadAnim: ((any) -> ())?,
	JammedAnim: ((any) -> ())?,
	PumpAnim: ((any) -> ())?,
	HighReady: ((any) -> ())?,
	LowReady: ((any) -> ())?,
	Patrol: ((any) -> ())?,
	meleeAttack: ((any) -> ())?,
	GrenadeReady: ((any) -> ())?,
	GrenadeThrow: ((any) -> ())?,
	[string]: any,
}

export type WeaponState = {
	-- Tool/Model references
	WeaponInHand: Model?,
	WeaponTool: Tool?,
	WeaponData: any,
	AnimData: WeaponAnimData?,
	ProceduralWeaponAnimator: any?,

	-- Viewmodel parts
	ViewModel: Model?,
	AnimPart: BasePart?,
	LArm: BasePart?,
	RArm: BasePart?,
	LArmWeld: Motor6D?,
	RArmWeld: Motor6D?,
	GunWeld: Motor6D?,

	-- Ammo
	Ammo: number,
	StoredAmmo: number,

	-- Spread / Recoil
	BSpread: number,
	RecoilPower: number,
	LastSpreadUpdate: number,

	-- Fire control
	generateBullet: number,
	charspeed: number,
	running: boolean,
	runKeyDown: boolean,
	aiming: boolean,
	shooting: boolean,
	reloading: boolean,
	mouse1down: boolean,
	AnimDebounce: boolean,
	CancelReload: boolean,
	SafeMode: boolean,
	JumpDelay: boolean,
	NVG: boolean,
	GunStance: number,
	AimPartMode: number,
	CurAimpart: BasePart?,
	Suppressor: boolean,
	FlashHider: boolean,
	UnderBarrelAtt: Model?,
	LaserActive: boolean,
	IRmode: boolean,
	IREnable: boolean,
	Pointer: Part?,
	BipodAtt: boolean,
	CanBipod: boolean,
	BipodActive: boolean,
	GRDebounce: boolean,
	CheckingMag: boolean,
	ToolEquip: boolean,
	Sens: number,
	Power: number,
	BipodCF: CFrame,
	NearZ: CFrame,

	-- CFrame offsets
	maincf: CFrame,
	guncf: CFrame,
	gunbobcf: CFrame,
	recoilcf: CFrame,
	aimcf: CFrame,

	-- Stance / Lean
	Stances: number,
	Virar: number,
	CameraX: number,
	CameraY: number,
	Sentado: boolean,
	Swimming: boolean,
	Steady: boolean,
	ChangeStance: boolean,

	-- Viewmodel caches
	viewModelEnabledStates: { [Instance]: boolean },
	viewModelTransparencyStates: { [Instance]: number },

	-- Tracers
	Tracers: number,
}

local function createDefaultState(): WeaponState
	return {
		WeaponInHand = nil,
		WeaponTool = nil,
		WeaponData = nil,
		AnimData = nil,
		ProceduralWeaponAnimator = nil,
		ViewModel = nil,
		AnimPart = nil,
		LArm = nil,
		RArm = nil,
		LArmWeld = nil,
		RArmWeld = nil,
		GunWeld = nil,
		Ammo = 0,
		StoredAmmo = 0,
		BSpread = 0,
		RecoilPower = 0,
		LastSpreadUpdate = 0,
		generateBullet = 1,
		charspeed = 0,
		running = false,
		runKeyDown = false,
		aiming = false,
		shooting = false,
		reloading = false,
		mouse1down = false,
		AnimDebounce = false,
		CancelReload = false,
		SafeMode = false,
		JumpDelay = false,
		NVG = false,
		GunStance = 0,
		AimPartMode = 1,
		CurAimpart = nil,
		Suppressor = false,
		FlashHider = false,
		UnderBarrelAtt = nil,
		LaserActive = false,
		IRmode = false,
		IREnable = false,
		Pointer = nil,
		BipodAtt = false,
		CanBipod = false,
		BipodActive = false,
		GRDebounce = false,
		CheckingMag = false,
		ToolEquip = false,
		Sens = 50,
		Power = 150,
		BipodCF = CFrame.new(),
		NearZ = CFrame.new(0, 0, -0.5),
		maincf = CFrame.new(),
		guncf = CFrame.new(),
		gunbobcf = CFrame.new(),
		recoilcf = CFrame.new(),
		aimcf = CFrame.new(),
		Stances = 0,
		Virar = 0,
		CameraX = 0,
		CameraY = 0,
		Sentado = false,
		Swimming = false,
		Steady = false,
		ChangeStance = true,
		viewModelEnabledStates = {},
		viewModelTransparencyStates = {},
		Tracers = 0,
	}
end

return {
	createDefaultState = createDefaultState,
}
