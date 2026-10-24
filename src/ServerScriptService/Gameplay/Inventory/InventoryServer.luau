--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)

local InventoryServer = {}
local Started = false
local Disconnect: (() -> ())? = nil

local function PlayerOwnsTool(Player: Player, Tool: Tool): boolean
	local Backpack = Player:FindFirstChildOfClass("Backpack")
	if Backpack and Tool:IsDescendantOf(Backpack) then
		return true
	end

	local Character = Player.Character
	return Character ~= nil and Tool:IsDescendantOf(Character)
end

local function RemoveTool(Player: Player, Tool: Instance?)
	if not Tool or not Tool:IsA("Tool") then
		warn(`[InventoryServer] {Player.Name} sent RemoveTool with an invalid tool`)
		return
	end

	if not PlayerOwnsTool(Player, Tool) then
		warn(`[InventoryServer] {Player.Name} targeted unowned tool {Tool:GetFullName()}`)
		return
	end

	Tool:Destroy()
end

function InventoryServer.Start()
	if Started then
		return
	end

	Disconnect = NetworkGuard.Listen(Packets.packets.InventoryAction, "InventoryAction", {
		Rate = 8,
		Burst = 12,
		Validate = function(Payload)
			return type(Payload) == "table"
				and Payload.action == "RemoveTool"
				and (Payload.tool == nil or typeof(Payload.tool) == "Instance")
		end,
	}, function(Payload, Player)
		RemoveTool(Player, Payload.tool)
	end)
	Started = true
end

function InventoryServer.Destroy()
	if Disconnect then
		Disconnect()
		Disconnect = nil
	end
	Started = false
end

return InventoryServer
