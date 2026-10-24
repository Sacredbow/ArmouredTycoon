--!strict
--[[
	@class Packets

	@desc
	Single source of truth for all networked communication.
	Aggregates packet/query definitions from child modules and
	registers them under a single Bytenet namespace.

	Usage:
	```lua
	local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
	Packets.packets.Notification.sendTo({ kind = "info", message = "Hello" }, player)
	Packets.queries.RedeemCode.invoke({ code = "STARTER" })
	```

	Architecture:
	- Each child module returns a function(ByteNet) -> { [string]: definition }
	- init.luau merges all groups into a single namespace at require time
	- Types live in Types.luau; import via require(Network.Packets.Types)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--local function WaitForClientNamespace(): boolean

--	local storage = ReplicatedStorage:WaitForChild("BytenetStorage")
--	print("no")
--	print(ReplicatedStorage:GetChildren())
--	if not storage then
--		warn(`Bytenet namespace {"ArmouredTycoon"} was not ready: BytenetStorage did not replicate in time`)
--		return false
--	end

--	local namespaceValue = storage:FindFirstChild("ArmouredTycoon")
--	local deadline = os.clock() + 10
--	while os.clock() < deadline do
--		if namespaceValue and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= "" then
--			return true
--		end
--		namespaceValue = storage:FindFirstChild("ArmouredTycoon")
--		task.wait(0.05)
--	end

--	warn(`Bytenet namespace {"ArmouredTycoon"} was not ready before timeout`)
--	return false
--end

--if RunService:IsClient() and RunService:IsRunning() then
--	WaitForClientNamespace()
--end

local ByteNet = require(ReplicatedStorage.Packages["bytenet-max"])

-- Gather all packet/query definition groups from child modules.
-- Each module exports a function(ByteNet) -> { [string]: definition }.
local PacketGroups = {
	require(script.NotificationPackets),
	require(script.EnvironmentalPackets),
	require(script.GameEventPackets),
	require(script.ProfilePackets),
	require(script.NPCPackets),
	require(script.NukePackets),
	require(script.InventoryPackets),
	require(script.WorldPackets),
	require(script.CombatPackets),
	require(script.AdminPackets),
}

local QueryGroups = {
	require(script.CommerceQueries),
	require(script.SettingsQueries),
	require(script.BuildQueries),
}

-- Merge multiple definition tables, warning on duplicate names.
local function MergeDefinitions(groups: { (any) -> { [string]: any } }): { [string]: any }
	local merged: { [string]: any } = {}
	for _, group in groups do
		local definitions = group(ByteNet)
		for name, definition in definitions do
			if merged[name] ~= nil then
				warn(`[Packets] Duplicate definition name: {name}. Second wins.`)
			end
			merged[name] = definition
		end
	end
	return merged
end

local namespace = ByteNet.defineNamespace("ArmouredTycoon", function()
	return {
		packets = MergeDefinitions(PacketGroups),
		queries = MergeDefinitions(QueryGroups),
	}
end)

return namespace
