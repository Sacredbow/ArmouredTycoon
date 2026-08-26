--!strict
--[[
	@class Loader

	@desc
	Client bootstrapper. Waits for the ByteNet namespace to be ready before
	requiring packets (so client replicators can decode bytenet payloads),
	then runs the ModuleLoader to mount all UI systems.
	Also cleans up legacy UI containers (Window/ScreenGui/MainMenu)
	when the ClientReplicator signals.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Players = game:GetService("Players")

--// Constants

const NAMESPACE_NAME = "ArmouredTycoon"
const NAMESPACE_POLL_INTERVAL = 0.5

--// Modules

const ModuleLoader = require(ReplicatedStorage.Libraries.ModuleLoader)

--// Runtime State

const Player = Players.LocalPlayer
const ClientReplicator = ReplicatedStorage.Remotes.Interface:WaitForChild("ClientReplicator")

--// Internal Utilities

local function WaitForNamespace(): boolean
	while true do
		const Storage = ReplicatedStorage:FindFirstChild("BytenetStorage")
		const NamespaceValue = Storage and Storage:FindFirstChild(NAMESPACE_NAME)
		if NamespaceValue and NamespaceValue:IsA("StringValue") and NamespaceValue.Value ~= "" then
			return true
		end

		task.wait(NAMESPACE_POLL_INTERVAL)
	end

	return false
end

local function EnsurePacketsReady()
	task.defer(function()
		if not WaitForNamespace() then
			warn("[Loader] Bytenet namespace never became ready; packets may not decode")
			return
		end

		const PacketsOk, PacketsError = pcall(function()
			require(ReplicatedStorage.Network.Packets)
		end)
		if not PacketsOk then
			warn(`[Loader] Network packets unavailable after startup: {PacketsError}`)
		end
	end)
end

local function ClearLegacyUI()
	ClientReplicator.OnClientEvent:Connect(function()
		for _, Instance in Player.PlayerGui:GetChildren() do
			if Instance.Name == "Window" or Instance.Name == "ScreenGui" or Instance.Name == "MainMenu" then
				Instance:Destroy()
			end
		end
	end)
end

--// Bootstrap

EnsurePacketsReady()
ClearLegacyUI()
ModuleLoader()
