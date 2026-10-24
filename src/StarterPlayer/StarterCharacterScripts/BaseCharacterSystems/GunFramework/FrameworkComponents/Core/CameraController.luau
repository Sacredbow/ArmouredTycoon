--!strict
--[[
	@class CameraController

	@desc
	Owns camera-level transforms: neck rotation, camera spring recoil,
	third-person viewmodel visibility, and the lean spring.
]]

--// Services

const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")
const RuntimeSettings = require(game:GetService("ReplicatedStorage").Shared.Platform.Settings.RuntimeSettings)

--// Constants

const AIM_RIG_PITCH_SCALE = 0.72
const NECK_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
const ANIM_BASE_TWEEN_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local CameraController = {}
CameraController.__index = CameraController

export type CameraController = typeof(setmetatable({} :: {
	_player: Player,
	_camera: Camera,
	_character: Model,
	_neck: Motor6D?,
	_acsClient: Instance?,
	_humanoid: Humanoid,
	_humanoidRootPart: BasePart?,
	_torso: BasePart?,
	_thirdPerson: boolean,
	_halfStep: boolean,
	_viewModel: Model?,
	_viewModelDescendants: { Instance },
	_viewModelEnabledStates: { [Instance]: boolean },
	_viewModelTransparencyStates: { [Instance]: number },
	_viewModelVisible: boolean?,
	_leanSpring: any,
	_leanPeekFactor: number,
	_leanDirPeek: number,
}, CameraController))

function CameraController.new(player: Player, camera: Camera, character: Model, humanoid: Humanoid, humanoidRootPart: BasePart?, torso: BasePart?, acsClient: Instance?): CameraController
	local self = setmetatable({
		_player = player,
		_camera = camera,
		_character = character,
		_neck = torso and torso:FindFirstChild("Neck") :: Motor6D?,
		_acsClient = acsClient,
		_humanoid = humanoid,
		_humanoidRootPart = humanoidRootPart,
		_torso = torso,
		_thirdPerson = RuntimeSettings.GetBoolean("Third Person", true),
		_halfStep = false,
		_viewModel = nil,
		_viewModelDescendants = {},
		_viewModelEnabledStates = {},
		_viewModelTransparencyStates = {},
		_viewModelVisible = nil,
		_leanSpring = nil,
		_leanPeekFactor = math.rad(-15),
		_leanDirPeek = 0,
	}, CameraController)

	return self
end

function CameraController:setCamera(camera: Camera)
	self._camera = camera
end

function CameraController:setViewModel(viewModel: Model?)
	self._viewModel = viewModel
	self._viewModelDescendants = if viewModel then viewModel:GetDescendants() else {}
	self._viewModelEnabledStates = {}
	self._viewModelTransparencyStates = {}
end

function CameraController:isThirdPerson(): boolean
	return self._thirdPerson
end

function CameraController:updateThirdPersonSetting()
	self._thirdPerson = RuntimeSettings.GetBoolean("Third Person", true)
end

function CameraController:applyCameraMode()
	self:updateThirdPersonSetting()
	if self._thirdPerson then
		self._player.CameraMode = Enum.CameraMode.Classic
	else
		self._player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

function CameraController:setViewModelVisible(visible: boolean)
	if not self._viewModel then
		return
	end

	if self._viewModelVisible == visible then
		return
	end

	self._viewModelVisible = visible
	for _, descendant in self._viewModelDescendants do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if visible then 0 else 1
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") then
			if self._viewModelEnabledStates[descendant] == nil then
				self._viewModelEnabledStates[descendant] = descendant.Enabled
			end
			descendant.Enabled = if visible then self._viewModelEnabledStates[descendant] else false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			if self._viewModelTransparencyStates[descendant] == nil then
				self._viewModelTransparencyStates[descendant] = descendant.Transparency
			end
			descendant.Transparency = if visible then self._viewModelTransparencyStates[descendant] else 1
		end
	end
end

function CameraController:headMovement(toolEquip: boolean, aiming: boolean, weaponData: any, acsClient: Instance?, deltaTime: number?)
	if not self._player or not self._humanoidRootPart or not self._humanoid or self._humanoid.Health <= 0 then
		return
	end

	if self._humanoid.RigType == Enum.HumanoidRigType.R15 then
		return
	end

	if not self._acsClient or self._acsClient:GetAttribute("Collapsed") then
		return
	end

	local cameraDirection = self._humanoidRootPart.CFrame:toObjectSpace(self._camera.CFrame).lookVector
	if not self._neck or not self._torso then
		return
	end

	self._halfStep = not self._halfStep

	local neckCFrame = CFrame.new(0, -0.5, 0)
		* CFrame.Angles(0, math.asin(cameraDirection.X) / 1.15, 0)
		* CFrame.Angles(-math.asin(self._camera.CFrame.LookVector.Y) + math.asin(self._torso.CFrame.LookVector.Y), 0, 0)
		* CFrame.Angles(math.rad(-90), 0, math.rad(180))

	local smoothingDelta = math.clamp(deltaTime or (1 / 60), 1 / 240, 0.1)
	local neckAlpha = 1 - math.exp(-smoothingDelta / 0.2)
	self._neck.C1 = self._neck.C1:Lerp(neckCFrame, neckAlpha)

	local aimingRig = toolEquip and aiming and weaponData and weaponData.Type == "Gun"
	local aimPitch = if aimingRig then math.clamp(math.asin(self._camera.CFrame.LookVector.Y), -1.1, 1.1) else 0

	local animBase = self._character:FindFirstChild("AnimBase")
	local animBaseW = animBase and animBase:FindFirstChild("AnimBaseW")
	if animBaseW and animBaseW:IsA("Motor6D") then
		local animBaseAlpha = 1 - math.exp(-smoothingDelta / 0.16)
		local targetC0 = CFrame.Angles(aimPitch * AIM_RIG_PITCH_SCALE, 0, 0)
		animBaseW.C0 = animBaseW.C0:Lerp(targetC0, animBaseAlpha)
	end

	if not self._halfStep then
		return
	end

	return neckCFrame, aimPitch, aimingRig == true
end

function CameraController:renderCam(cameraSpring: any)
	self._camera.CFrame = self._camera.CFrame * CFrame.Angles(
		cameraSpring.p.x,
		cameraSpring.p.y,
		cameraSpring.p.z
	)
end

function CameraController:updateLean(leanSpring: any, leanDirection: number)
	if not leanSpring then
		return
	end

	leanSpring.cornerPeek.t = self._leanPeekFactor * leanDirection
	local newLeanCF = CFrame.fromAxisAngle(Vector3.new(0, 0, 1), leanSpring.cornerPeek.p)
	self._camera.CFrame = self._camera.CFrame * newLeanCF
end

return CameraController
