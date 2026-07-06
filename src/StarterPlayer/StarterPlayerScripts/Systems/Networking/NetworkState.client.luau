local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.janitor)

local latestStats = {}
local janitor = Janitor.new()

janitor:Add(script.Destroying:Connect(function()
	janitor:Destroy()
	table.clear(latestStats)
end), "Disconnect", "Destroying")

local function packetsNamespaceReady(): boolean
	local storage = ReplicatedStorage:FindFirstChild("BytenetStorage")
	local namespaceValue = storage and storage:FindFirstChild("ArmouredTycoon")
	return namespaceValue ~= nil and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= ""
end

janitor:Add(task.spawn(function()
	local Packets = nil
	while not Packets do
		if packetsNamespaceReady() then
			local ok, result = pcall(function()
				return require(ReplicatedStorage.Network.Packets)
			end)
			if ok then
				Packets = result
			else
				task.wait(0.5)
			end
		else
			task.wait(0.5)
		end
	end

	janitor:Add(Packets.packets.StatSync.listen(function(data)
		latestStats[data.stat] = data.value
	end), true, "StatSync")

	janitor:Add(Packets.packets.WeaponState.listen(function(_data)
		-- Weapon visuals still use the ACS remotes; this listener keeps ByteNet initialized for new UI.
	end), true, "WeaponState")
end), true, "StartupThread")

return {
	GetStat = function(statName: string): number?
		return latestStats[statName]
	end,

	Destroy = function()
		janitor:Destroy()
		table.clear(latestStats)
	end,
}
