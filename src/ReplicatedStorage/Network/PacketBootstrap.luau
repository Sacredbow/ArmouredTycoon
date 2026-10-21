--!strict
--[[
	Shared client ByteNet readiness boundary.
	Consumers that must register listeners call Get(); UI polling paths call TryGet().
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMESPACE_NAME = "ArmouredTycoon"
local cachedPackets: any = nil

local function namespaceReady(): boolean
	local storage = ReplicatedStorage:FindFirstChild("BytenetStorage")
	local namespaceValue = storage and storage:FindFirstChild(NAMESPACE_NAME)
	return namespaceValue ~= nil and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= ""
end

local function requirePackets(): any?
	local ok, result = pcall(function()
		return require(ReplicatedStorage.Network.Packets)
	end)
	if ok then
		cachedPackets = result
		return result
	end
	return nil
end

local PacketBootstrap = {}

function PacketBootstrap.TryGet(): any?
	if cachedPackets then
		return cachedPackets
	end
	if not namespaceReady() then
		return nil
	end
	return requirePackets()
end

function PacketBootstrap.Get(): any
	while not cachedPackets do
		if namespaceReady() then
			if requirePackets() then
				break
			end
		end
		task.wait(0.25)
	end
	return cachedPackets
end

return PacketBootstrap