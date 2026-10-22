--!strict

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Administrator = ServerStorage:WaitForChild("AdminRegistry")
local ClientReplicator = ReplicatedStorage.Remotes.Interface:WaitForChild("ClientReplicator")
local Janitor = require(ReplicatedStorage.Packages.janitor)

-- UserId authorization is immutable and does not change when a username does.
local Admins = table.freeze({
	[1372952359] = true,
})

local Janitors: { [Player]: any } = {}

local function attachAdminUi(player: Player)
	if not Admins[player.UserId] then
		return
	end

	local oldJanitor = Janitors[player]
	if oldJanitor then
		oldJanitor:Destroy()
	end

	local janitor = Janitor.new()
	Janitors[player] = janitor

	local function onCharacterAdded()
		if not player.Parent then
			return
		end

		local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
		local mainModule = Administrator:FindFirstChild("MainModule")
		if mainModule and playerGui.Parent then
			mainModule:Clone().Parent = playerGui
		end
		ClientReplicator:FireClient(player)
	end

	janitor:Add(player.CharacterAdded:Connect(onCharacterAdded), "Disconnect", "CharacterAdded")
	if player.Character then
		onCharacterAdded()
	end
end

for _, player in Players:GetPlayers() do
	attachAdminUi(player)
end

Players.PlayerAdded:Connect(attachAdminUi)
Players.PlayerRemoving:Connect(function(player)
	local janitor = Janitors[player]
	if janitor then
		janitor:Destroy()
		Janitors[player] = nil
	end
end)
