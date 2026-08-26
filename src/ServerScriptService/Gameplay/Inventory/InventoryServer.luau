--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Network.Packets)
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

	print("[InventoryServer] Removing tool", tool.Name, "from", player.Name)
	tool:Destroy()
end

function InventoryServer:Start()
	if self._started then
		return
	end

	self._started = true
	Packets.packets.InventoryAction.listen(function(payload, player: Player)
	if payload.action == "RemoveTool" then
			self:_removeTool(player, payload.tool)
		else
			warn(`[InventoryServer] {player.Name} sent unknown action: {tostring(payload.action)}`)
		end
	end)
end

return InventoryServer
