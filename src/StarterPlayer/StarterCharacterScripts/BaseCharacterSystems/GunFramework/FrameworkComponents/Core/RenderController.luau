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
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const PacketBootstrap = require(ReplicatedStorage.Shared.Platform.Network.PacketBootstrap)
const Packets = PacketBootstrap.Get()

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
	_cachedWeapon: Instance?,
	_sightMarks: { BasePart },
	_laserPoints: { BasePart },
	_aimPart: BasePart?,
	_nvAim: Instance?,
	_cachedPointer: Part?,
	_pointerBeam: Beam?,
	_reticleBorders: { [BasePart]: GuiObject? },
	_lastFovTarget: number?,
	_fovTween: Tween?,
}, RenderController))

function RenderController.new(camera: Camera, ctx: RenderContext): RenderController
	return setmetatable({
		_camera = camera,
		_ctx = ctx,
		_cachedWeapon = nil,
		_sightMarks = {},
		_laserPoints = {},
		_aimPart = nil,
		_nvAim = nil,
		_cachedPointer = nil,
		_pointerBeam = nil,
		_reticleBorders = {},
		_lastFovTarget = nil,
		_fovTween = nil,
	}, RenderController)
end

function RenderController:setCamera(camera: Camera)
	if self._camera == camera then
		return
	end

	if self._fovTween then
		self._fovTween:Cancel()
		self._fovTween = nil
	end

	self._camera = camera
	self._lastFovTarget = nil
end

function RenderController:_refreshWeaponCaches(weapon: Instance)
	if self._cachedWeapon == weapon then
		return
	end

	self._cachedWeapon = weapon
	table.clear(self._sightMarks)
	table.clear(self._laserPoints)
	table.clear(self._reticleBorders)
	self._aimPart = nil
	self._nvAim = nil
	local aimPart = weapon:FindFirstChild("AimPart")
	if aimPart and aimPart:IsA("BasePart") then
		self._aimPart = aimPart
		local nvAim = aimPart:FindFirstChild("NVAim")
		if nvAim and (nvAim:IsA("BasePart") or nvAim:IsA("Attachment")) then
			self._nvAim = nvAim
		end
	end
	for _, descendant in weapon:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.Name == "SightMark" then
				table.insert(self._sightMarks, descendant)
				local surfaceGui = descendant:FindFirstChild("SurfaceGui")
				local border = surfaceGui and surfaceGui:FindFirstChild("Border")
				self._reticleBorders[descendant] = if border and border:IsA("GuiObject") then border else nil
			elseif descendant.Name == "LaserPoint" then
				table.insert(self._laserPoints, descendant)
			end
		end
	end
end

function RenderController:_setFovTarget(target: number)
	if self._lastFovTarget == target then
		return
	end

	self._lastFovTarget = target
	if self._fovTween then
		self._fovTween:Cancel()
	end
	self._fovTween = TweenService:Create(self._camera, self._ctx.aimTween, { FieldOfView = target })
	self._fovTween:Play()
end

function RenderController:destroy()
	if self._fovTween then
		self._fovTween:Cancel()
		self._fovTween = nil
	end
	self._cachedWeapon = nil
	self._cachedPointer = nil
	self._pointerBeam = nil
	self._aimPart = nil
	self._nvAim = nil
	table.clear(self._sightMarks)
	table.clear(self._laserPoints)
	table.clear(self._reticleBorders)
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
	local smoothingDelta = math.clamp(deltaTime, 1 / 240, 0.1)
	local smoothingAlpha = 1 - math.exp(-smoothingDelta * 13.4)
	local bobAlpha = 1 - math.exp(-smoothingDelta * 6.32)

	ctx.state.halfStep = not ctx.state.halfStep

	-- Camera spring recoil
	camera.CFrame = camera.CFrame * CFrame_Angles(ctx.cameraSpring.p.x, ctx.cameraSpring.p.y, ctx.cameraSpring.p.z)

	local weaponInHand = equip:getWeaponInHand()
	local animData = equip:getAnimData()
	local weaponData = equip:getWeaponData()
	local viewModel = equip:getViewModel()

	if not viewModel or not weaponInHand then
		self._cachedWeapon = nil
		table.clear(self._sightMarks)
		table.clear(self._laserPoints)
		return
	end
	self:_refreshWeaponCaches(weaponInHand)

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
						ctx.bipodCF = ctx.bipodCF:Lerp(CFrame_new(0, ((underBarrel.Main.Position - bipodPos).Magnitude - 1) * (-1.5), 0), smoothingAlpha)
					else
						ctx.bipodCF = ctx.bipodCF:Lerp(CFrame_new(), smoothingAlpha)
					end
				else
					equip:setBipodActive(false)
					equip:setCanBipod(false)
					ctx.bipodCF = ctx.bipodCF:Lerp(CFrame_new(), smoothingAlpha)
				end
			else
				equip:setBipodActive(false)
				equip:setCanBipod(false)
				ctx.bipodCF = ctx.bipodCF:Lerp(CFrame_new(), smoothingAlpha)
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
		), bobAlpha)
	else
		ctx.gunbobcf = ctx.gunbobcf:Lerp(CFrame_new(
			0.005 * math_sin(tick() * 1.5),
			0.005 * math_cos(tick() * 2.5),
			0
		), bobAlpha)
	end

	-- ADS aim
	local curAimpart = equip:getCurAimpart()
	if curAimpart and ctx.state.aiming and ctx.state.animDebounce and not equip:getCheckingMag() then
		local aimPart = self._aimPart
		local nvAim = self._nvAim
		if not ctx.state.nvg or not aimPart or not nvAim then
			if equip:getAimPartMode() == 1 then
				if not ctx.isThirdPersonCamera() then
					self:_setFovTarget(equip:getModTable().ZoomValue)
				end
				ctx.maincf = ctx.maincf:Lerp(ctx.maincf * CFrame_new(0, 0, -0.5) * ctx.recoilcf * sway:inverse() * curAimpart.CFrame:toObjectSpace(camera.CFrame), smoothingAlpha)
			else
				if not ctx.isThirdPersonCamera() then
					self:_setFovTarget(equip:getModTable().Zoom2Value)
				end
				ctx.maincf = ctx.maincf:Lerp(ctx.maincf * CFrame_new(0, 0, -0.5) * ctx.recoilcf * sway:inverse() * curAimpart.CFrame:toObjectSpace(camera.CFrame), smoothingAlpha)
			end
		else
			if not ctx.isThirdPersonCamera() then
				self:_setFovTarget(70)
			end
			local nvAimCFrame = if nvAim:IsA("BasePart") or nvAim:IsA("Attachment") then nvAim.CFrame else aimPart.CFrame
			ctx.maincf = ctx.maincf:Lerp(ctx.maincf * CFrame_new(0, 0, -0.5) * ctx.recoilcf * sway:inverse() * (aimPart.CFrame * nvAimCFrame):toObjectSpace(camera.CFrame), smoothingAlpha)
		end
	else
		if not ctx.isThirdPersonCamera() then
			self:_setFovTarget(70)
		end
		ctx.maincf = ctx.maincf:Lerp((animData and animData.MainCFrame or CFrame_new()) * ctx.recoilcf * sway:inverse(), smoothingAlpha)
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
	for _, part in self._sightMarks do
		if part.Parent then
			local distScale = part.CFrame:PointToObjectSpace(camera.CFrame.Position) / part.Size
			local border = self._reticleBorders[part]
			if border then
				border.Position = UDim2.new(0.5 + distScale.X, 0, 0.5 - distScale.Y, 0)
			end
		end
	end

	-- Recoil spring recovery
	ctx.recoilcf = ctx.recoilcf:Lerp(CFrame_new() * CFrame_Angles(
		math_rad(ctx.recoilSpring.p.X),
		math_rad(ctx.recoilSpring.p.Y),
		math_rad(ctx.recoilSpring.p.z)
	), smoothingAlpha)

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
		if self._cachedPointer ~= pointer then
			self._cachedPointer = pointer
			local beam = pointer and pointer:FindFirstChild("Beam")
			self._pointerBeam = if beam and beam:IsA("Beam") then beam else nil
		end
		if ctx.state.nvg then
			pointer.Transparency = 0
			if self._pointerBeam then
				self._pointerBeam.Enabled = true
			end
		else
			if not ctx.gameRules.RealisticLaser then
				if self._pointerBeam then
				self._pointerBeam.Enabled = true
			end
			else
				if self._pointerBeam then
				self._pointerBeam.Enabled = false
			end
			end
			if equip:getIRMode() then
				pointer.Transparency = 1
			else
				pointer.Transparency = 0
			end
		end

		for _, key in self._laserPoints do
			if key.Parent then
				local laserResult = ctx.runtime.raycast(key.CFrame.Position, key.CFrame.LookVector * 1000, ctx.ignoreModel)
				local pos = laserResult and laserResult.Position or (camera.CFrame.Position + key.CFrame.LookVector * 2000)
				local normal = laserResult and laserResult.Normal or key.CFrame.LookVector
				pointer.CFrame = CFrame.new(pos, pos + normal)
				if ctx.state.halfStep and ctx.gameRules.ReplicatedLaser then
					Packets.packets.LaserIntent.send({ position = pos, mode = 1, color = pointer.Color, infrared = equip:getIRMode(), weapon = equip:getWeaponTool() })
				end
				break
			end
		end
	end
end

return RenderController
