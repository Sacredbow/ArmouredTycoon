local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local NewSettingsGui = PlayerGui:WaitForChild("NewSettings", 10)

local SettingsBackground
local ResetFrame

if NewSettingsGui then
	SettingsBackground = NewSettingsGui:WaitForChild("SettingsBackground")
	ResetFrame = SettingsBackground:WaitForChild("Reset")
else
	warn("NewSettings GUI failed to load")
end

-- Ensure Reset frame has a UIScale for pop animation
local resetScale
if ResetFrame and not ResetFrame:FindFirstChild("SettingsAnimScale") then
	resetScale = Instance.new("UIScale")
	resetScale.Name = "SettingsAnimScale"
	resetScale.Scale = 0
	resetScale.Parent = ResetFrame
elseif ResetFrame then
	resetScale = ResetFrame:FindFirstChild("SettingsAnimScale")
end

local ANIMATION_SPEED = 0.3
local BLUR_SIZE = 24

-- Store the home position of SettingsBackground
local SETTINGS_HOME = UDim2.new(0.5, 0, 0.5, 0)
local SETTINGS_OFFSCREEN = UDim2.new(0.5, 0, 1.5, 0)

local AnimationController = {}

function AnimationController.AnimateBlurSize(size)
	local blur = Lighting:FindFirstChild("BackgroundBlur")
	if not blur then return end

	TweenService:Create(
		blur,
		TweenInfo.new(ANIMATION_SPEED / 2),
		{Size = size}
	):Play()
end

function AnimationController.AnimateMenu(direction, menuName)
	if not SettingsBackground then
		warn("Cannot animate menu - NewSettings GUI not loaded")
		return
	end

	if menuName == "Settings" then
		local frame = SettingsBackground
		local tweenInfo, goal

		if direction == "In" then
			AnimationController.AnimateBlurSize(BLUR_SIZE)
			frame.Position = SETTINGS_OFFSCREEN
			frame.Visible = true
			tweenInfo = TweenInfo.new(ANIMATION_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			goal = {Position = SETTINGS_HOME}
		else
			AnimationController.AnimateBlurSize(0)
			tweenInfo = TweenInfo.new(ANIMATION_SPEED / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			goal = {Position = SETTINGS_OFFSCREEN}
		end

		local tween = TweenService:Create(frame, tweenInfo, goal)
		tween:Play()
		tween.Completed:Wait()

		if direction == "Out" then
			frame.Visible = false
		end
	elseif menuName == "Reset" then
		if not ResetFrame or not resetScale then return end

		local tweenInfo, goal

		if direction == "In" then
			ResetFrame.Visible = true
			resetScale.Scale = 0
			tweenInfo = TweenInfo.new(ANIMATION_SPEED, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			goal = {Scale = 1}
		else
			tweenInfo = TweenInfo.new(ANIMATION_SPEED / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			goal = {Scale = 0}
		end

		local tween = TweenService:Create(resetScale, tweenInfo, goal)
		tween:Play()
		tween.Completed:Wait()

		if direction == "Out" then
			ResetFrame.Visible = false
		end
	end
end

return AnimationController