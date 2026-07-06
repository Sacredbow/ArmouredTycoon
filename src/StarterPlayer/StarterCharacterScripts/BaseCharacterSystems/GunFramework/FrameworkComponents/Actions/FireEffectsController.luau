

--[[
	FireEffectsController

	Applies the local visual/audio/mechanical effects of a confirmed shot. This
	module is intentionally downstream from ShootingController: by the time code
	reaches here, Main has already decided that the weapon is allowed to fire.

	Responsibilities:
		- choose suppressed/normal muzzle audio
		- emit muzzle/chamber/shell particles
		- tween slide lock movement
		- grow spread and recoil counters after each shot
		- return the updated counters back to Main

	It does not create hit rays or subtract ammo. Those remain outside so bullet
	networking, server damage, and legacy ACS callbacks stay in one known place.
]]

local TweenService = game:GetService("TweenService")

local FireEffectsController = {}

export type WeaponData = {
	MaxSpread: number,
	AimInaccuracyStepAmount: number,
	MaxRecoilPower: number,
	RecoilPowerStepAmount: number,
	ShootRate: number,
	SlideLock: boolean?,
	SlideEx: CFrame,
}

export type Modifiers = {
	MaxSpread: number,
	AimInaccuracyStepAmount: number,
	MaxRecoilPower: number,
	RecoilPowerStepAmount: number,
}

export type SpreadState = {
	bSpread: number?,
	recoilPower: number?,
	generateBullet: number,
	lastSpreadUpdate: number,
}

local function emit(parent: Instance, name: string, count: number)
	-- Particle names follow legacy ACS models, so missing emitters are acceptable.
	local child = parent:FindFirstChild(name)
	if child and child:IsA("ParticleEmitter") then
		child:Emit(count)
	end
end

local function play(parent: Instance, name: string)
	-- Sound lookups are defensive for suppressor/custom barrel variants.
	local child = parent:FindFirstChild(name)
	if child and child:IsA("Sound") then
		child:Play()
	end
end

function FireEffectsController.apply(
	weaponModel: Model,
	weaponData: WeaponData,
	modifiers: Modifiers,
	ammo: number,
	suppressor: boolean,
	flashHider: boolean,
	state: SpreadState
): SpreadState
	-- Handle is the effect root for ACS gun models. If it is missing, the weapon
	-- can still fail gracefully instead of throwing during input.
	local handle = weaponModel:FindFirstChild("Handle")
	if not handle then
		return state
	end

	local muzzle = handle:FindFirstChild("Muzzle")
	if muzzle then
		if suppressor then
			play(muzzle, "Supressor")
		else
			play(muzzle, "Fire")
		end

		if not flashHider then
			emit(muzzle, "FlashFX[Flash]", 10)
		end

		emit(muzzle, "Smoke", 10)
	end

	local bSpread = state.bSpread
	local recoilPower = state.recoilPower
	if bSpread and recoilPower then
		bSpread = math.min(weaponData.MaxSpread * modifiers.MaxSpread, bSpread + weaponData.AimInaccuracyStepAmount * modifiers.AimInaccuracyStepAmount)
		recoilPower = math.min(weaponData.MaxRecoilPower * modifiers.MaxRecoilPower, recoilPower + weaponData.RecoilPowerStepAmount * modifiers.RecoilPowerStepAmount)
	end

	local slideMotor = handle:FindFirstChild("Slide")
	if slideMotor and slideMotor:IsA("Motor6D") then
		local shouldLockOpen = ammo <= 0 and weaponData.SlideLock == true
		TweenService:Create(
			slideMotor,
			TweenInfo.new(30 / weaponData.ShootRate, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, not shouldLockOpen, 0),
			{ C0 = weaponData.SlideEx:Inverse() }
		):Play()
	end

	local chamber = handle:FindFirstChild("Chamber")
	if chamber then
		emit(chamber, "Smoke", 10)
		emit(chamber, "Shell", 1)
	end

	return {
		bSpread = bSpread,
		recoilPower = recoilPower,
		generateBullet = state.generateBullet + 1,
		lastSpreadUpdate = time(),
	}
end

return FireEffectsController
