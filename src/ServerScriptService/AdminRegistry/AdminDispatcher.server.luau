--!strict

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Administrator = ServerStorage:WaitForChild("AdminRegistry")
local ClientReplicator = ReplicatedStorage.Remotes.Interface:WaitForChild("ClientReplicator")

-- UserId authorization is immutable and does not change when a username does.
local Admins = table.freeze({
	[1372952359] = true,
})

local function attachAdminUi(player: Player)
	if not Admins[player.UserId] then
		return
	end

	local function onCharacterAdded()
		local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
		local mainModule = Administrator:FindFirstChild("MainModule")
		if mainModule then
			mainModule:Clone().Parent = playerGui
		end
		ClientReplicator:FireClient(player)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded()
	end
end

for _, player in Players:GetPlayers() do
	attachAdminUi(player)
end
Players.PlayerAdded:Connect(attachAdminUi)