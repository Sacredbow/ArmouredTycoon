--!strict
--[[
	@class RenderController

	@desc
	Owns the first-person viewmodel render pipeline that used to live inline
	in Main's RenderStepped step. It composites bob, sway, bipod, ADS/scope,
	recoil recovery, spread recovery, and the laser pointer into the camera
	and viewmodel.

	Main constructs one RenderController per character spawn and calls
	Step(deltaTime) from its RenderStepped binding. All mutable state it
	needs is passed in via a context table so it never reaches into Main.
]]

--// Services

const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")

--// Micro-Optimisations

const CFrame_new = CFrame.new
const CFrame_Angles = CFrame.Angles
const math_rad = math.rad
const math_sin = math.sin
const math_cos = math.cos
const math_max = math.max
const time = time
const tick = tick

--// Types

export type RenderContext = {
	-- Controller / module dependencies
	cameraController: any,
	equipController: any,
	featureFlags: any,
	runtime: any,
	gameRules: any,
	events: any,

	-- Raycast ignore list (shared with CastController)
	ignoreModel: { Instance },

	-- Springs owned by Main
	cameraSpring: any,
	swaySpring: any,
	recoilSpring: any,

	-- Mutable viewmodel CFrames (accumulators)
	gunbobcf: CFrame,
	recoilcf: CFrame,
	aimcf: CFrame,
	maincf: CFrame,
	bipodCF: CFrame,
	nearZ: CFrame,

	-- ADS field-of-view tween
	aimTween: TweenInfo,

	-- Shared mutable flags (mirrors Main's state table)
	state: {
		aiming: boolean,
		running: boolean,
		runKeyDown: boolean,
		shooting: boolean,
		animDebounce: boolean,
		nvg: boolean,
		halfStep: boolean,
		gunStance: number,
		charspeed: number,
	},

	-- Callbacks back into Main
	isThirdPersonCamera: () -> boolean,
	updateCrosshair: () -> (),
}

local RenderController = {}
RenderController.__index = RenderController

export type RenderController = typeof(setmetatable({} :: {
	_camera: Camera,
	_ctx: RenderContext,
}, RenderController))

function RenderController.new(camera: Camera, ctx: RenderContext): RenderController
	return setmetatable({
		_camera = camera,
		_ctx = ctx,
	}, RenderController)
end

--// Recoil accessors (Main pushes authored recoil CFrames through here)

function RenderController:setRecoilCF(cf: CFrame)
	self._ctx.recoilcf = cf
end

function RenderController:getRecoilCF(): CFrame
	return self._ctx.recoilcf
end

function RenderController:reset()
	local ctx = self._ctx
	ctx.gunbobcf = CFrame_new()
	ctx.recoilcf = CFrame_new()
	ctx.aimcf = CFrame_new()
	ctx.maincf = CFrame_new()
	ctx.bipodCF = CFrame_new()
end

--// Main pipeline

function RenderController:step(deltaTime: number)
	local ctx = self._ctx
	local equip = ctx.equipController
	local camera = self._camera

	ctx.state.halfStep = not ctx.state.halfStep

	-- Camera spring recoil
	camera.CFrame = camera.CFrame * CFrame_Angles(ctx.cameraSpring.p.x, ctx.cameraSpring.p.y, ctx.cameraSpring.p.z)

	local weaponInHand = equip:getWeaponInHand()
	local animData = equip:getAnimData()
	local weaponData = equip:getWeaponData()
	local viewModel = equip:getViewModel()

	if not viewModel or not weaponInHand then
		return
	end

	ctx.cameraController:setViewModelVisible(not ctx.isThirdPersonCamera())

	local mouseDelta = UserInputService:GetMouseDelta()
	if not ctx.state.aiming then
		ctx.swaySpring:accelerate(Vector3.new(mouseDelta.X / 60, mouseDelta.Y / 60, 0))
	end

	local swayVec = ctx.swaySpring.p
	local sway = CFrame_Angles(swayVec.Y, swayVec.X, swayVec.X)

	-- Bipod raycast
	if ctx.featureFlags.WeaponUtilitiesEnabled and equip:getBipodAtt() then
		local underBarrel = equip:getUnderBarrelAtt()
		if underBarrel and underBarrel:FindFirstChild("Main") then
			local bipodResult = ctx.runtime.raycast(underBarrel.Main.Position, Vector3.new(0, -1.75, 0), ctx.ignoreModel)
			local bipodHit = bipodResult and bipodResult.Instance
			local bipodPos = bipodResult and bipodResult.Position
			if bipodHit and bipodPos then
				equip:setCanBipod(true)
				if equip:getCanBipod() and equip:getBipodActive() and not ctx.state.runKeyDown and (ctx.state.gunStance == 0 or ctx.state.gunStance == 2) then
					if not ctx.state.aiming then
						ctx.bipodCF = ctx.bipodCF:Lerp(CFrame_new(0, ((underBarrel.Main.Position - bipodPos).Magnitude - 1) * (-1.5), 0), 0.2)
					else
						ctx.bipodCF = ctx.bipodCF:Lerp(CFrame_new(), 0.2)
					end
				else
					equip:setBipodActive(false)
					equip:setCanBipod(false)
					ctx.bipodCF = ctx.bipodCF:Lerp(CFrame_new(), 0.2)
				end
			else
				equip:setBipodActive(false)
				equip:setCanBipod(false)
				ctx.bipodCF = ctx.bipodCF:Lerp(CFrame_new(), 0.2)
			end
		end
	end

	-- Movement bob
	local charspeed = ctx.state.charspeed
	if ctx.state.running then
		ctx.gunbobcf = ctx.gunbobcf:Lerp(CFrame_new(
			0.025 * (charspeed / 10) * math_sin(tick() * 8),
			0.025 * (charspeed / 10) * math_cos(tick() * 16),
			0
		) * CFrame_Angles(
			math_rad(1 * (charspeed / 10) * math_sin(tick() * 16)),
			math_rad(1 * (charspeed / 10) * math_cos(tick() * 8)),
			math_rad(0)
		), 0.1)
	else
		ctx.gunbobcf = ctx.gunbobcf:Lerp(CFrame_new(
			0.005 * math_sin(tick() * 1.5),
			0.005 * math_cos(tick() * 2.5),
			0
		), 0.1)
	end

	-- ADS aim
	local curAimpart = equip:getCurAimpart()
	if curAimpart and ctx.state.aiming and ctx.state.animDebounce and not equip:getCheckingMag() then
		if not ctx.state.nvg or (weaponInHand:FindFirstChild("AimPart") and not weaponInHand.AimPart:FindFirstChild("NVAim")) then
			if equip:getAimPartMode() == 1 then
				if not ctx.isThirdPersonCamera() then
					TweenService:Create(camera, ctx.aimTween, { FieldOfView = equip:getModTable().ZoomValue }):Play()
				end
				ctx.maincf = ctx.maincf:Lerp(ctx.maincf * CFrame_new(0, 0, -0.5) * ctx.recoilcf * sway:inverse() * curAimpart.CFrame:toObjectSpace(camera.CFrame), 0.2)
			else
				if not ctx.isThirdPersonCamera() then
					TweenService:Create(camera, ctx.aimTween, { FieldOfView = equip:getModTable().Zoom2Value }):Play()
				end
				ctx.maincf = ctx.maincf:Lerp(ctx.maincf * CFrame_new(0, 0, -0.5) * ctx.recoilcf * sway:inverse() * curAimpart.CFrame:toObjectSpace(camera.CFrame), 0.2)
			end
		else
			if not ctx.isThirdPersonCamera() then
				TweenService:Create(camera, ctx.aimTween, { FieldOfView = 70 }):Play()
			end
			ctx.maincf = ctx.maincf:Lerp(ctx.maincf * CFrame_new(0, 0, -0.5) * ctx.recoilcf * sway:inverse() * (weaponInHand.AimPart.CFrame * weaponInHand.AimPart.NVAim.CFrame):toObjectSpace(camera.CFrame), 0.2)
		end
	else
		if not ctx.isThirdPersonCamera() then
			TweenService:Create(camera, ctx.aimTween, { FieldOfView = 70 }):Play()
		end
		ctx.maincf = ctx.maincf:Lerp((animData and animData.MainCFrame or CFrame_new()) * ctx.recoilcf * sway:inverse(), 0.2)
	end

	equip:setMainCF(ctx.maincf)

	-- AnimPart follows camera
	local animPart = viewModel.PrimaryPart
	if animPart then
		animPart.CFrame = camera.CFrame * ctx.nearZ * ctx.bipodCF * ctx.maincf * ctx.gunbobcf * ctx.aimcf
	end

	-- Weapon model positioning
	if not animData or not animData.GunModelFixed then
		weaponInHand:SetPrimaryPartCFrame(animPart.CFrame * equip:getGunCF())
	end

	-- Scope reticle parallax
	for _, part in weaponInHand:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "SightMark" then
			local distScale = part.CFrame:pointToObjectSpace(camera.CFrame.Position) / part.Size
			local reticle = part:FindFirstChild("SurfaceGui")
			if reticle and reticle:IsA("SurfaceGui") then
				local border = reticle:FindFirstChild("Border")
				if border then
					border.Position = UDim2.new(0.5 + distScale.X, 0, 0.5 - distScale.Y, 0)
				end
			end
		end
	end

	-- Recoil spring recovery
	ctx.recoilcf = ctx.recoilcf:Lerp(CFrame_new() * CFrame_Angles(
		math_rad(ctx.recoilSpring.p.X),
		math_rad(ctx.recoilSpring.p.Y),
		math_rad(ctx.recoilSpring.p.z)
	), 0.2)

	-- Crosshair update
	ctx.updateCrosshair()

	-- Spread/recoil recovery
	local bSpread = equip:getBSpread()
	if bSpread and weaponData then
		local currTime = time()
		local lastSpreadUpdate = equip:getLastSpreadUpdate()
		if currTime - lastSpreadUpdate > (60 / weaponData.ShootRate) * 2 and not ctx.state.shooting and bSpread > weaponData.MinSpread * equip:getModTable().MinSpread then
			equip:setBSpread(math_max(weaponData.MinSpread * equip:getModTable().MinSpread, bSpread - weaponData.AimInaccuracyDecrease * equip:getModTable().AimInaccuracyDecrease))
		end
		local recoilPower = equip:getRecoilPower()
		if currTime - lastSpreadUpdate > (60 / weaponData.ShootRate) * 1.5 and not ctx.state.shooting and recoilPower > weaponData.MinRecoilPower * equip:getModTable().MinRecoilPower then
			equip:setRecoilPower(math_max(weaponData.MinRecoilPower * equip:getModTable().MinRecoilPower, recoilPower - weaponData.RecoilPowerStepAmount * equip:getModTable().RecoilPowerStepAmount))
		end
	end

	-- Laser pointer
	if equip:getLaserActive() and equip:getPointer() ~= nil then
		local pointer = equip:getPointer()
		if ctx.state.nvg then
			pointer.Transparency = 0
			if pointer:FindFirstChild("Beam") then
				pointer.Beam.Enabled = true
			end
		else
			if not ctx.gameRules.RealisticLaser then
				if pointer:FindFirstChild("Beam") then
					pointer.Beam.Enabled = true
				end
			else
				if pointer:FindFirstChild("Beam") then
					pointer.Beam.Enabled = false
				end
			end
			if equip:getIRMode() then
				pointer.Transparency = 1
			else
				pointer.Transparency = 0
			end
		end

		for _, key in weaponInHand:GetDescendants() do
			if key:IsA("BasePart") and key.Name == "LaserPoint" then
				local laserResult = ctx.runtime.raycast(key.CFrame.Position, key.CFrame.LookVector * 1000, ctx.ignoreModel)
				local pos = laserResult and laserResult.Position or (camera.CFrame.Position + key.CFrame.LookVector * 2000)
				local normal = laserResult and laserResult.Normal or key.CFrame.LookVector
				pointer.CFrame = CFrame.new(pos, pos + normal)
				if ctx.state.halfStep and ctx.gameRules.ReplicatedLaser then
					ctx.events.SVLaser:FireServer(pos, 1, pointer.Color, equip:getIRMode(), equip:getWeaponTool())
				end
				break
			end
		end
	end
end

return RenderController
