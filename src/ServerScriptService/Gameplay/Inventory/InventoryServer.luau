--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packets = require(ReplicatedStorage.Network.Packets)
local NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)
local InventoryServer = {}
InventoryServer.__index = InventoryServer

function InventoryServer.new()
	return setmetatable({
		_started = false,
	}, InventoryServer)
end

local function playerOwnsTool(player: Player, tool: Tool): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and tool:IsDescendantOf(backpack) then
		return true
	end

	local character = player.Character
	return character ~= nil and tool:IsDescendantOf(character)
end

function InventoryServer:_removeTool(player: Player, tool: Instance?)
	if not tool or not tool:IsA("Tool") then
		warn(`[InventoryServer] {player.Name} sent RemoveTool with an invalid tool`)
		return
	end

	if not playerOwnsTool(player, tool) then
		warn(`[InventoryServer] {player.Name} targeted unowned tool {tool:GetFullName()}`)
		return
	end

	tool:Destroy()
end

function InventoryServer:Start()
	if self._started then
		return
	end

	self._disconnect = NetworkGuard.Listen(
		Packets.packets.InventoryAction,
		"InventoryAction",
		{
			Rate = 8,
			Burst = 12,
			Validate = function(payload)
				return type(payload) == "table" and payload.action == "RemoveTool"
			end,
		},
		function(payload, player)
			self:_removeTool(player, payload.tool)
		end
	)
	self._started = true
end

function InventoryServer:Destroy()
	if self._disconnect then
		self._disconnect()
		self._disconnect = nil
	end
	self._started = false
end
return InventoryServer
