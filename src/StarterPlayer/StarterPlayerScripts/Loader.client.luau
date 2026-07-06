local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ModuleLoader = require(ReplicatedStorage.Libraries.ModuleLoader)
local player = game.Players.LocalPlayer
local ClientReplicator = ReplicatedStorage.Remotes.Interface:WaitForChild("ClientReplicator")

task.defer(function()
	while true do
		local storage = ReplicatedStorage:FindFirstChild("BytenetStorage")
		local namespaceValue = storage and storage:FindFirstChild("ArmouredTycoon")
		if namespaceValue and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= "" then
			break
		end

		task.wait(0.5)
	end

	local packetsOk, packetsError = pcall(function()
		require(ReplicatedStorage.Network.Packets)
	end)
	if not packetsOk then
		warn(`[Loader] Network packets unavailable after startup: {packetsError}`)
	end
end)

ModuleLoader()


ClientReplicator.OnClientEvent:Connect(function()
	for _, v in player.PlayerGui:GetChildren() do
		if v.Name == "Window" or v.Name == "ScreenGui" or v.Name == "MainMenu" then
			v:Destroy()
		end
	end
	
end)
