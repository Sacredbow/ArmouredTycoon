--!strict

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Observers = require(ReplicatedStorage.Packages.Observers)
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)

local Administrator = ServerStorage:WaitForChild("AdminRegistry")

local Janitor = require(ReplicatedStorage.Packages.janitor)

-- UserId authorization is immutable and does not change when a username does.
local Admins = table.freeze({
	[1372952359] = true,
})

local Janitors: { [Player]: any } = {}

local function attachAdminUi(player: Player)
	if not Admins[player.UserId] then
		return function() end
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
		Packets.packets.AdminUiReady.sendTo(nil, player)
	end

	janitor:Add(player.CharacterAdded:Connect(onCharacterAdded), "Disconnect", "CharacterAdded")
	if player.Character then
		onCharacterAdded()
	end

	return function()
		local currentJanitor = Janitors[player]
		if currentJanitor then
			currentJanitor:Destroy()
			Janitors[player] = nil
		end
	end
end
Observers.observePlayer(function(player: Player)
	return attachAdminUi(player)
end)
