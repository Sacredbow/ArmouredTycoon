--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local App = require(script.Parent.App)

local DEBUG_REACT_UI = true
local CUSTOM_INVENTORY_ENABLED = false

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function debugPrint(message: string, ...: any)
	if DEBUG_REACT_UI then
		print("[ArmouredReactUI]", message, ...)
	end
end

local function disableRobloxBackpack()
	task.spawn(function()
		for attempt = 1, 12 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)

			if ok then
				debugPrint("Roblox backpack disabled from React root", "attempt", attempt)
				return
			end

			debugPrint("Backpack CoreGui not ready from React root, retrying", attempt)
			task.wait(0.25)
		end

		warn("[ArmouredReactUI] Failed to disable Roblox backpack from React root.")
	end)
end

local function enableRobloxBackpack()
	task.spawn(function()
		for attempt = 1, 12 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
			end)

			if ok then
				
				return
			end

			debugPrint("Backpack CoreGui not ready from React root, retrying enable", attempt)
			task.wait(0.25)
		end

		warn("[ArmouredReactUI] Failed to enable Roblox backpack from React root.")
	end)
end

local existingRoot = playerGui:FindFirstChild("ArmouredReactUI")
if existingRoot then
	debugPrint("Destroying existing ArmouredReactUI root before remount")
	existingRoot:Destroy()
end

if CUSTOM_INVENTORY_ENABLED then
	disableRobloxBackpack()
else
	enableRobloxBackpack()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ArmouredReactUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 2000
screenGui.Parent = playerGui
debugPrint("Created ScreenGui", screenGui:GetFullName())

local root = ReactRoblox.createRoot(screenGui)
root:render(React.createElement(App))
debugPrint("Rendered React app")

script.Destroying:Connect(function()
	root:unmount()
	if screenGui.Parent then
		screenGui:Destroy()
	end
end)
