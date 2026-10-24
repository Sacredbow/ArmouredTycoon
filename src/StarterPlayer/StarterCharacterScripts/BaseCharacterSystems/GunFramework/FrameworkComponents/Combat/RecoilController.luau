--!strict

--[[
	RecoilController

	Calculates camera and viewmodel recoil impulses. Main owns the springs, but
	this module decides how strongly to push them based on weapon settings, aiming,
	bipod state, and attachment modifiers.
]]

local RecoilController = {}

export type RecoilContext = {
	WeaponData: any,
	ModTable: any,
	BipodActive: boolean,
	Aiming: boolean,
	RecoilPower: number,
	CameraSpring: any,
	RecoilSpring: any,
	RecoilCFrame: CFrame,
	RandomRange: (number, number, number?) -> number,
	Schedule: (number, () -> ()) -> (),
}

-- applies camera and weapon recoil, then returns the new recoil cframe
function RecoilController.apply(context: RecoilContext): CFrame
	local weaponData = context.WeaponData
	local modTable = context.ModTable

	local vr = (math.random(weaponData.camRecoil.camRecoilUp[1], weaponData.camRecoil.camRecoilUp[2]) / 2)
		* modTable.camRecoilMod.RecoilUp
	local lr = math.random(weaponData.camRecoil.camRecoilLeft[1], weaponData.camRecoil.camRecoilLeft[2])
		* modTable.camRecoilMod.RecoilLeft
	local rr = math.random(weaponData.camRecoil.camRecoilRight[1], weaponData.camRecoil.camRecoilRight[2])
		* modTable.camRecoilMod.RecoilRight
	local hr = math.random(-rr, lr) / 2
	local tr = (math.random(weaponData.camRecoil.camRecoilTilt[1], weaponData.camRecoil.camRecoilTilt[2]) / 2)
		* modTable.camRecoilMod.RecoilTilt

	local recoilX = math.rad(vr * context.RandomRange(1, 1, 0.1))
	local recoilY = math.rad(hr * context.RandomRange(-1, 1, 0.1))
	local recoilZ = math.rad(tr * context.RandomRange(-1, 1, 0.1))

	local gvr = (math.random(weaponData.gunRecoil.gunRecoilUp[1], weaponData.gunRecoil.gunRecoilUp[2]) / 10)
		* modTable.gunRecoilMod.RecoilUp
	local gdr = (
		math.random(-1, 1)
		* math.random(weaponData.gunRecoil.gunRecoilTilt[1], weaponData.gunRecoil.gunRecoilTilt[2])
		/ 10
	) * modTable.gunRecoilMod.RecoilTilt
	local glr = math.random(weaponData.gunRecoil.gunRecoilLeft[1], weaponData.gunRecoil.gunRecoilLeft[2])
		* modTable.gunRecoilMod.RecoilLeft
	local grr = math.random(weaponData.gunRecoil.gunRecoilRight[1], weaponData.gunRecoil.gunRecoilRight[2])
		* modTable.gunRecoilMod.RecoilRight
	local ghr = math.random(-grr, glr) / 10

	local aimReduction = weaponData.AimRecoilReduction * modTable.AimRM
	local recoilPower = context.RecoilPower
	local recoilCFrame = context.RecoilCFrame

	if context.BipodActive then
		context.CameraSpring:accelerate(Vector3.new(recoilX, recoilY / 2, 0))

		if context.Aiming then
			context.RecoilSpring:accelerate(
				Vector3.new(
					math.rad(0.25 * gvr * recoilPower / aimReduction),
					math.rad(0.25 * ghr * recoilPower / aimReduction),
					math.rad(0.25 * gdr / aimReduction)
				)
			)
			recoilCFrame *= CFrame.new(0, 0, 0.1) * CFrame.Angles(
				math.rad(0.25 * gvr * recoilPower / aimReduction),
				math.rad(0.25 * ghr * recoilPower / aimReduction),
				math.rad(0.25 * gdr * recoilPower / aimReduction)
			)
		else
			context.RecoilSpring:accelerate(
				Vector3.new(
					math.rad(0.25 * gvr * recoilPower),
					math.rad(0.25 * ghr * recoilPower),
					math.rad(0.25 * gdr)
				)
			)
			recoilCFrame *= CFrame.new(0, 0, 0.1) * CFrame.Angles(
				math.rad(0.25 * gvr * recoilPower),
				math.rad(0.25 * ghr * recoilPower),
				math.rad(0.25 * gdr * recoilPower)
			)
		end

		context.Schedule(0.05, function()
			context.CameraSpring:accelerate(Vector3.new(-recoilX, -recoilY / 2, 0))
		end)
	else
		context.CameraSpring:accelerate(Vector3.new(recoilX, recoilY, recoilZ))

		if context.Aiming then
			context.RecoilSpring:accelerate(
				Vector3.new(
					math.rad(gvr * recoilPower / aimReduction),
					math.rad(ghr * recoilPower / aimReduction),
					math.rad(gdr / aimReduction)
				)
			)
			recoilCFrame *= CFrame.new(0, 0, 0.1) * CFrame.Angles(
				math.rad(gvr * recoilPower / aimReduction),
				math.rad(ghr * recoilPower / aimReduction),
				math.rad(gdr * recoilPower / aimReduction)
			)
		else
			context.RecoilSpring:accelerate(
				Vector3.new(math.rad(gvr * recoilPower), math.rad(ghr * recoilPower), math.rad(gdr))
			)
			recoilCFrame *= CFrame.new(0, -0.05, 0.1) * CFrame.Angles(
				math.rad(gvr * recoilPower),
				math.rad(ghr * recoilPower),
				math.rad(gdr * recoilPower)
			)
		end
	end

	return recoilCFrame
end

return RecoilController
