--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local CameraShaker = require(ReplicatedStorage.Libraries.CameraShaker)
local PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local shaker = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCFrame)
	if camera then
		camera.CFrame *= shakeCFrame
	end
end)
shaker:Start()

local activeConnection: RBXScriptConnection?
local restoredCameraType: Enum.CameraType? = nil
local restoredSubject: Instance? = nil
local flashGui: ScreenGui? = nil
local terminalConnection: RBXScriptConnection? = nil
local nukeLightingConnection: RBXScriptConnection? = nil
local launchStartedAt = 0
local savedLighting: { ClockTime: number, Brightness: number, ExposureCompensation: number, Ambient: Color3, OutdoorAmbient: Color3 }? = nil

local function getCamera(): Camera?
	camera = Workspace.CurrentCamera
	return camera
end

local function makeFlash()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	if flashGui and flashGui.Parent then
		flashGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "NukeFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9500
	gui.Parent = playerGui

	local flash = Instance.new("TextLabel")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.Font = Enum.Font.GothamBlack
	flash.Size = UDim2.fromScale(1, 1)
	flash.Text = "IMPACT"
	flash.TextColor3 = Color3.fromRGB(255, 255, 255)
	flash.TextScaled = true
	flash.TextTransparency = 0.08
	flash.Parent = gui

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "NukeOverexposure"
	bloom.Intensity = 8
	bloom.Size = 64
	bloom.Threshold = 0
	bloom.Parent = game:GetService("Lighting")

	task.delay(8.2, function()
		if flash.Parent then
			TweenService:Create(flash, TweenInfo.new(2.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}):Play()
		end
	end)
	TweenService:Create(bloom, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Intensity = 0,
		Threshold = 1.8,
	}):Play()

	task.delay(10.5, function()
		if gui.Parent then
			gui:Destroy()
		end
		if bloom.Parent then
			bloom:Destroy()
		end
	end)

	flashGui = gui
end

local function tweenNukeNight()
	if savedLighting then
		return
	end

	savedLighting = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		ExposureCompensation = Lighting.ExposureCompensation,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}

	TweenService:Create(Lighting, TweenInfo.new(4.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		ClockTime = 0.35,
		Brightness = math.max(0.35, Lighting.Brightness * 0.45),
		ExposureCompensation = -0.35,
		Ambient = Color3.fromRGB(34, 38, 62),
		OutdoorAmbient = Color3.fromRGB(18, 22, 36),
	}):Play()

	if nukeLightingConnection then
		nukeLightingConnection:Disconnect()
	end

	nukeLightingConnection = RunService.RenderStepped:Connect(function()
		Lighting.ClockTime = 0.35
		Lighting.ExposureCompensation = -0.35
	end)
end

local function restoreNukeLighting()
	local lighting = savedLighting
	if not lighting then
		return
	end

	savedLighting = nil
	if nukeLightingConnection then
		nukeLightingConnection:Disconnect()
		nukeLightingConnection = nil
	end
	TweenService:Create(Lighting, TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), lighting):Play()
end

local function restoreCamera()
	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end
	if terminalConnection then
		terminalConnection:Disconnect()
		terminalConnection = nil
	end
	restoreNukeLighting()

	local currentCamera = getCamera()
	if currentCamera then
		currentCamera.CameraType = restoredCameraType or Enum.CameraType.Custom
		currentCamera.CameraSubject = restoredSubject
	end
end

local function getRootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end

	return nil
end

local function startLaunchCamera(sourcePosition: Vector3, targetPosition: Vector3, role: string?)
	local currentCamera = getCamera()
	if not currentCamera then
		return
	end

	restoredCameraType = currentCamera.CameraType
	restoredSubject = currentCamera.CameraSubject
	currentCamera.CameraType = Enum.CameraType.Scriptable

	if activeConnection then
		activeConnection:Disconnect()
	end

	launchStartedAt = os.clock()
	activeConnection = RunService.RenderStepped:Connect(function()
		local cam = getCamera()
		if not cam then
			return
		end

		local elapsed = os.clock() - launchStartedAt
		local launchAlpha = math.clamp((elapsed - 4) / 4, 0, 1)
		local predictedRocket = sourcePosition
			+ Vector3.new(0, 90 * math.clamp(elapsed / 4, 0, 1) + 1250 * (launchAlpha ^ 0.42), 0)
		local cameraPosition: Vector3
		if elapsed < 6 then
			cameraPosition = sourcePosition + Vector3.new(34, 18, 58)
		elseif elapsed < 12 then
			cameraPosition = sourcePosition + Vector3.new(-52, 90, 72)
		else
			cameraPosition = sourcePosition:Lerp(targetPosition, 0.16) + Vector3.new(120, 190, 105)
		end

		cam.CFrame = CFrame.lookAt(cameraPosition, predictedRocket)
	end)
end

local function startTerminalCuts(sourcePosition: Vector3, targetPosition: Vector3)
	local currentCamera = getCamera()
	if not currentCamera then
		return
	end

	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end
	if terminalConnection then
		terminalConnection:Disconnect()
	end

	currentCamera.CameraType = Enum.CameraType.Scriptable
	local startedAt = os.clock()
	local cutDurations = { 2.3, 2.0, 1.72, 1.45, 1.2, 1.0, 0.82, 0.68, 0.52, 0.36 }
	local cutEnds = table.create(#cutDurations)
	local running = 0
	for index, duration in ipairs(cutDurations) do
		running += duration
		cutEnds[index] = running
	end

	terminalConnection = RunService.RenderStepped:Connect(function()
		local cam = getCamera()
		if not cam then
			return
		end

		local elapsed = os.clock() - startedAt
		local cutIndex = #cutEnds
		for index, cutEnd in ipairs(cutEnds) do
			if elapsed <= cutEnd then
				cutIndex = index
				break
			end
		end

		local rootPosition = getRootPosition() or targetPosition
		local descentAlpha = math.clamp(elapsed / 15, 0, 1)
		local slowHold = math.clamp(descentAlpha / 0.72, 0, 1)
		local strike = math.clamp((descentAlpha - 0.72) / 0.28, 0, 1) ^ 2.45
		local highPosition = targetPosition + Vector3.new(170, 1180, -280)
		local commitPosition = targetPosition + Vector3.new(52, 620, -86)
		local nukePosition = if descentAlpha < 0.72
			then highPosition:Lerp(commitPosition, slowHold)
			else commitPosition:Lerp(targetPosition + Vector3.new(0, 28, 0), strike)

		if cutIndex % 3 == 1 then
			local offset = Vector3.new(0, 6, 16)
			cam.CFrame = CFrame.lookAt(rootPosition + offset, rootPosition + Vector3.new(0, 2.5, 0))
		elseif cutIndex % 3 == 2 then
			local offset = Vector3.new(24, 32, 62)
			cam.CFrame = CFrame.lookAt(nukePosition + offset, nukePosition)
		else
			local offset = Vector3.new(-42, 26, 34)
			cam.CFrame = CFrame.lookAt(nukePosition + offset, nukePosition + Vector3.new(0, -90, 0))
		end
	end)
end

Packets.packets.NukeCinematic.listen(function(payload)
	if payload.action == "Focus" and payload.sourcePosition and payload.targetPosition then
		startLaunchCamera(payload.sourcePosition, payload.targetPosition, payload.role)
		shaker:ShakeOnce(1.6, 4, 0.4, 3, Vector3.new(0.25, 0.22, 0.25), Vector3.new(0.7, 0.5, 0.7))
		task.delay(5, tweenNukeNight)
	elseif payload.action == "Phase" and payload.phase == "launch" then
		shaker:ShakeOnce(6.5, 11, 0.15, 5.5, Vector3.new(1.05, 0.85, 1.05), Vector3.new(3, 2, 3))
	elseif payload.action == "Phase" and payload.phase == "terminal" and payload.sourcePosition and payload.targetPosition then
		startTerminalCuts(payload.sourcePosition, payload.targetPosition)
	elseif payload.action == "MashStart" then
		shaker:ShakeOnce(3.5, 8, 0.2, 9, Vector3.new(0.7, 0.55, 0.7), Vector3.new(2, 1.3, 2))
	elseif payload.action == "Impact" then
		makeFlash()
		shaker:ShakeOnce(13, 22, 0.05, 6, Vector3.new(1.8, 1.45, 1.8), Vector3.new(5, 3.6, 5))
	elseif payload.action == "End" then
		restoreCamera()
	end
end)
