--!strict
--[[
	@class Loader

	@desc
	Client bootstrapper. Waits for the ByteNet namespace to be ready before
	waiting for the shared ByteNet namespace,
	then runs the ModuleLoader to mount all UI systems.
	Also cleans up legacy UI containers (Window/ScreenGui/MainMenu)
	when the admin UI is mounted.
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


--// Internal Utilities

local function EnsurePacketsReady()
	PacketBootstrap.Get()
end
local function ClearLegacyUI()
	local function clear()
		for _, Instance in Player.PlayerGui:GetChildren() do
			if Instance.Name == "Window" or Instance.Name == "ScreenGui" or Instance.Name == "MainMenu" then
				Instance:Destroy()
			end
		end
	end

	clear()

	local Packets = PacketBootstrap.TryGet()
	local packet = Packets and Packets.packets.AdminUiReady
	if packet then
		packet.listen(clear)
	end
end

--// Bootstrap

EnsurePacketsReady()
ClearLegacyUI()
ModuleLoader()
