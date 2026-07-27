--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage.Modules.SettingsManager.SettingsConfig)
local RuntimeSettings = require(ReplicatedStorage.Modules.SettingsManager.RuntimeSettings)
local ClientRuntimeState = require(ReplicatedStorage.Modules.ClientRuntimeState)

local player = Players.LocalPlayer

local ACS_AIMING_ATTRIBUTE = "ACS_Aiming"

type CameraMode = "FirstPerson" | "ThirdPerson"

local FIRST_PERSON: CameraMode = "FirstPerson"
local THIRD_PERSON: CameraMode = "ThirdPerson"

type CameraProfile = {
	minZoom: number,
	maxZoom: number,
	offset: Vector3,
	aimOffset: Vector3,
	aimFovDelta: number,
	offsetSpeed: number,
	fovSpeed: number,
}

local THIRD_PERSON_PROFILE: CameraProfile = {
	minZoom = 7.25,
	maxZoom = 9.75,
	offset = Vector3.new(1.65, 1.05, 0),
	aimOffset = Vector3.new(2.25, 1.18, -0.18),
	aimFovDelta = -7,
	offsetSpeed = 10,
	fovSpeed = 9,
}

local FIRST_PERSON_PROFILE: CameraProfile = {
	minZoom = 0.5,
	maxZoom = 0.5,
	offset = Vector3.zero,
	aimOffset = Vector3.zero,
	aimFovDelta = 0,
	offsetSpeed = 16,
	fovSpeed = 12,
}

local activeHumanoid: Humanoid? = nil
local currentOffset = Vector3.zero
local defaultFov = SettingsConfig.default_settings["Field of View"]
local currentFov = if typeof(defaultFov) == "number" then defaultFov else 60
local defaultMinZoom = player.CameraMinZoomDistance
local defaultMaxZoom = player.CameraMaxZoomDistance
local lastDebugState = ""

local function expAlpha(speed: number, deltaTime: number): number
	return 1 - math.exp(-speed * deltaTime)
end

local function getBaseFov(): number
	return math.clamp(RuntimeSettings.GetNumber('Field of View', currentFov), 30, 90)
end

local function getCameraMode(): CameraMode
	if not RuntimeSettings.GetBoolean('Third Person', SettingsConfig.default_settings['Third Person'] ~= false) then
		return FIRST_PERSON
	end

	return THIRD_PERSON
end

local function isAiming(): boolean
	return ClientRuntimeState.IsWeaponAiming(player)
end

local function hasEquippedAcsWeapon(character: Model?): boolean
	if not character then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:FindFirstChild("ACS_Settings") then
			return true
		end
	end

	return false
end

local function getProfile(mode: CameraMode): CameraProfile
	if mode == FIRST_PERSON then
		return FIRST_PERSON_PROFILE
	end

	return THIRD_PERSON_PROFILE
end

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 8)
	if humanoid and humanoid:IsA("Humanoid") then
		activeHumanoid = humanoid
		currentOffset = humanoid.CameraOffset
	end
end

local function applyCameraSubject(camera: Camera, humanoid: Humanoid)
	if camera.CameraType ~= Enum.CameraType.Custom then
		return
	end

	if camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
end

local function applyMouseBehavior(mode: CameraMode, hasWeapon: boolean)
	if UserInputService.TouchEnabled then
		return
	end

	-- Locking the cursor gives weapon users mouse-look without requiring RMB.
	-- Character facing is handled separately by setAimLockedFacing, so hip-fire
	-- third-person can rotate the camera freely without becoming shift-lock.
	if mode == FIRST_PERSON or (mode == THIRD_PERSON and hasWeapon) then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	elseif UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local function getRoot(character: Model?): BasePart?
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function setAimLockedFacing(character: Model?, humanoid: Humanoid, camera: Camera, enabled: boolean, deltaTime: number)
	if not enabled then
		if humanoid.AutoRotate ~= true then
			humanoid.AutoRotate = true
		end
		return
	end

	local root = getRoot(character)
	if not root then
		return
	end

	if humanoid.AutoRotate ~= false then
		humanoid.AutoRotate = false
	end

	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude <= 0.001 then
		return
	end

	local target = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
	root.CFrame = root.CFrame:Lerp(target, expAlpha(18, deltaTime))
end

local function printDebugState(mode: CameraMode, hasWeapon: boolean, aiming: boolean)
	local state = `{mode}:weapon={hasWeapon}:aim={aiming}`
	if state == lastDebugState then
		return
	end

	lastDebugState = state
	print("[GameplayCamera]", state)
end

local function setCameraMode(mode: Enum.CameraMode)
	if player.CameraMode ~= mode then
		player.CameraMode = mode
	end
end

local function setZoom(minZoom: number, maxZoom: number)
	if math.abs(player.CameraMinZoomDistance - minZoom) > 0.001 then
		player.CameraMinZoomDistance = minZoom
	end
	if math.abs(player.CameraMaxZoomDistance - maxZoom) > 0.001 then
		player.CameraMaxZoomDistance = maxZoom
	end
end

local function applyZoom(mode: CameraMode, aiming: boolean, profile: CameraProfile)
	if mode == FIRST_PERSON then
		setCameraMode(Enum.CameraMode.LockFirstPerson)
		setZoom(profile.minZoom, profile.maxZoom)
		return
	end

	setCameraMode(Enum.CameraMode.Classic)

	if aiming then
		setZoom(math.max(5.25, profile.minZoom - 1.1), math.max(6.75, profile.maxZoom - 2.35))
	else
		setZoom(profile.minZoom, profile.maxZoom)
	end
end

local function updateCamera(deltaTime: number)
	local camera = Workspace.CurrentCamera
	local humanoid = activeHumanoid
	local character = player.Character
	if not camera or not humanoid or humanoid.Health <= 0 then
		return
	end

	local hasWeapon = hasEquippedAcsWeapon(character)
	if not hasWeapon then
		RuntimeSettings.Set('CameraControllerOwnsOffset', false)
		printDebugState(THIRD_PERSON, false, false)
		setAimLockedFacing(character, humanoid, camera, false, deltaTime)
		applyMouseBehavior(THIRD_PERSON, false)
		setCameraMode(Enum.CameraMode.Classic)
		setZoom(defaultMinZoom, defaultMaxZoom)
		currentOffset = humanoid.CameraOffset
		return
	end

	local mode = getCameraMode()
	local profile = getProfile(mode)
	local aiming = isAiming()
	local aimLocked = mode == THIRD_PERSON and aiming
	local baseFov = getBaseFov()
	local targetFov = baseFov + (if aiming then profile.aimFovDelta else 0)

	printDebugState(mode, hasWeapon, aiming)
	applyCameraSubject(camera, humanoid)
	applyZoom(mode, aiming, profile)
	applyMouseBehavior(mode, hasWeapon)
	setAimLockedFacing(character, humanoid, camera, aimLocked, deltaTime)

	if mode == FIRST_PERSON then
		RuntimeSettings.Set('CameraControllerOwnsOffset', false)
		if humanoid.CameraOffset.Magnitude > 0.001 then
			humanoid.CameraOffset = Vector3.zero
		end
		currentOffset = Vector3.zero
		currentFov = camera.FieldOfView
		return
	end

	RuntimeSettings.Set('CameraControllerOwnsOffset', true)

	local targetOffset = if aiming then profile.aimOffset else profile.offset
	currentOffset = currentOffset:Lerp(targetOffset, expAlpha(profile.offsetSpeed, deltaTime))
	currentFov += (targetFov - currentFov) * expAlpha(profile.fovSpeed, deltaTime)

	humanoid.CameraOffset = currentOffset
	camera.FieldOfView = currentFov
end

player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(function()
	activeHumanoid = nil
	currentOffset = Vector3.zero
end)

if player.Character then
	task.defer(setupCharacter, player.Character)
end

RunService:BindToRenderStep("GameplayCameraController", Enum.RenderPriority.Camera.Value + 1, updateCamera)
