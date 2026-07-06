--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local CAMERA_OFFSET_SPEED = 7.5
local JOINT_SPEED = 8.5
local MAX_TORSO_YAW = math.rad(24)
local MAX_TORSO_PITCH = math.rad(10)
local GIVE_UP_YAW = math.rad(115)

local currentCameraOffset = Vector3.zero
local currentWaistTransform = CFrame.identity
local currentRootTransform = CFrame.identity

type Rig = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	waist: Motor6D?,
	rootJoint: Motor6D?,
}

local activeRig: Rig? = nil

local function expAlpha(speed: number, deltaTime: number): number
	return 1 - math.exp(-speed * deltaTime)
end

local function findMotor(parent: Instance?, name: string): Motor6D?
	if not parent then
		return nil
	end

	local motor = parent:FindFirstChild(name)
	if motor and motor:IsA("Motor6D") then
		return motor
	end

	return nil
end

local function hasEquippedACSWeapon(character: Model): boolean
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:FindFirstChild("ACS_Settings") then
			return true
		end
	end

	return false
end

local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 8)
	local root = character:WaitForChild("HumanoidRootPart", 8)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		activeRig = nil
		return
	end

	local upperTorso = character:FindFirstChild("UpperTorso")
	local lowerTorso = character:FindFirstChild("LowerTorso")
	local torso = character:FindFirstChild("Torso")

	activeRig = {
		character = character,
		humanoid = humanoid,
		root = root,
		waist = findMotor(upperTorso, "Waist") or findMotor(lowerTorso, "Waist"),
		rootJoint = findMotor(root, "RootJoint") or findMotor(torso, "RootJoint"),
	}
	currentCameraOffset = humanoid.CameraOffset
	currentWaistTransform = CFrame.identity
	currentRootTransform = CFrame.identity
end

local function getCameraRelative(root: BasePart): (number, number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0, 0
	end

	local look = root.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
	local yaw = math.atan2(-look.X, -look.Z)
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	return yaw, pitch
end

local function getTargetCameraOffset(rig: Rig): Vector3
	if hasEquippedACSWeapon(rig.character) then
		return Vector3.zero
	end

	local humanoid = rig.humanoid
	local moveDirection = humanoid.MoveDirection
	local localMove = rig.root.CFrame:VectorToObjectSpace(moveDirection)
	local yaw = getCameraRelative(rig.root)
	local turnLean = math.clamp(yaw / math.rad(70), -1, 1)
	local speedRatio = math.clamp(rig.root.AssemblyLinearVelocity.Magnitude / 18, 0, 1)

	local side = math.clamp(-localMove.X * 0.42 + turnLean * 0.22, -0.65, 0.65)
	local vertical = math.sin(os.clock() * 9.5) * 0.055 * speedRatio
	local forward = math.clamp(-math.abs(localMove.Z) * 0.08, -0.12, 0)

	return Vector3.new(side, vertical, forward)
end

local function updateCameraOffset(rig: Rig, deltaTime: number)
	if player:GetAttribute("CameraControllerOwnsOffset") == true then
		return
	end

	local target = getTargetCameraOffset(rig)
	currentCameraOffset = currentCameraOffset:Lerp(target, expAlpha(CAMERA_OFFSET_SPEED, deltaTime))
	rig.humanoid.CameraOffset = currentCameraOffset
end

local function updateBodyFacing(rig: Rig, deltaTime: number)
	local yaw, pitch = getCameraRelative(rig.root)
	local targetWaist = CFrame.identity
	local targetRoot = CFrame.identity

	if math.abs(yaw) < GIVE_UP_YAW then
		local yawAmount = math.clamp(yaw * 0.34, -MAX_TORSO_YAW, MAX_TORSO_YAW)
		local pitchAmount = math.clamp(-pitch * 0.28, -MAX_TORSO_PITCH, MAX_TORSO_PITCH)
		targetWaist = CFrame.Angles(pitchAmount, yawAmount, 0)
		targetRoot = CFrame.Angles(0, math.clamp(yaw * 0.08, -math.rad(5), math.rad(5)), 0)
	end

	local alpha = expAlpha(JOINT_SPEED, deltaTime)
	currentWaistTransform = currentWaistTransform:Lerp(targetWaist, alpha)
	currentRootTransform = currentRootTransform:Lerp(targetRoot, alpha)

	if rig.waist then
		rig.waist.Transform = currentWaistTransform
	end
	if rig.rootJoint then
		rig.rootJoint.Transform = currentRootTransform
	end
end

local function clearRig()
	if activeRig then
		activeRig.humanoid.CameraOffset = Vector3.zero
		if activeRig.waist then
			activeRig.waist.Transform = CFrame.identity
		end
		if activeRig.rootJoint then
			activeRig.rootJoint.Transform = CFrame.identity
		end
	end

	activeRig = nil
	currentCameraOffset = Vector3.zero
	currentWaistTransform = CFrame.identity
	currentRootTransform = CFrame.identity
end

player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(function()
	clearRig()
end)

if player.Character then
	task.defer(setupCharacter, player.Character)
end

RunService:BindToRenderStep("CharacterMotionController", Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
	local rig = activeRig
	if not rig or rig.humanoid.Health <= 0 or not rig.root.Parent then
		return
	end

	updateCameraOffset(rig, deltaTime)
	updateBodyFacing(rig, deltaTime)
end)
