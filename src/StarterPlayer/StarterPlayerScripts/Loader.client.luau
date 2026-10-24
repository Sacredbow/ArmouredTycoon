--!strict
-- Central client entrypoint. All client feature modules start through ClientBootstrap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PacketBootstrap = require(ReplicatedStorage.Shared.Platform.Network.PacketBootstrap)
local ClientBootstrap = require(script.Parent.Client.ClientBootstrap)

local Player = Players.LocalPlayer

local function ClearLegacyUI()
	local function Clear()
		for _, Instance in Player.PlayerGui:GetChildren() do
			if Instance.Name == "Window" or Instance.Name == "ScreenGui" or Instance.Name == "MainMenu" then
				Instance:Destroy()
			end
		end  
	Clear()

	local Packets = PacketBootstrap.TryGet()
	local Packet = Packets and Packets.packets.AdminUiReady
	if Packet then
		Packet.listen(Clear)
	end
end

PacketBootstrap.Get()
ClearLegacyUI()
ClientBootstrap.Start()
