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


--// Modules

const ModuleLoader = require(ReplicatedStorage.Libraries.ModuleLoader)
const PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)

--// Runtime State

const Player = Players.LocalPlayer
const ClientReplicator = ReplicatedStorage.Remotes.Interface:WaitForChild("ClientReplicator")

--// Internal Utilities

local function EnsurePacketsReady()
	task.defer(function()
		PacketBootstrap.Get()
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
