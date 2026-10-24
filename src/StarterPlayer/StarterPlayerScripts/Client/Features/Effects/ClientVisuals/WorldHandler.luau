--!strict
--[[
	@class WorldHandler

	@desc
	Client-side world visual handler. Listens for server-replicated build/deassemble
	events and executes procedural piece animations locally to eliminate server physics
	and replication overhead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildAssemble = require(ReplicatedStorage.Shared.Game.Tycoon.Building.BuildEffect)
local PacketBootstrap = require(ReplicatedStorage.Shared.Platform.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()

local function BuildInstance(data: { item: Instance, duration: number?, mode: string? })
	if not data or not data.item then
		return
	end

	if data.mode == "deassemble" then
		BuildAssemble.DeassembleClient(data.item, nil, {
			timingScale = if data.duration then nil else 1,
		})
	else
		BuildAssemble.PlayClient(data.item, nil, {
			timingScale = if data.duration then nil else 1,
		})
	end
end

if Packets.packets and Packets.packets.BuildAssemble then
	Packets.packets.BuildAssemble.listen(BuildInstance)
end
