local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local BanSignal = require(ServerScriptService.Signals.BanSignal)
local BanManager = require(script.Methods.BanManager)

local function RegisterCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local now = os.clock()

	ECS.createEntity({
		Name = player.Name .. ":AntiCheatState",
		Model = character,
		AntiCheatState = {
			player = player,
			character = character,
			humanoid = humanoid,
			humanoidRootPart = humanoidRootPart,
			readyAt = now + 10,
			elapsed = 0,
			lastPosition = humanoidRootPart.Position,
			lastInputTime = now,
			violations = 0,
			lastViolationTime = 0,
			noclipStrikes = 0,
			teleportStrikes = 0,
			positionHistory = {},
			tickCount = 0,
			cooldownUntil = 0,
		},
	})
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		RegisterCharacter(player, character)
	end)
end)
local function HandleBanRequest(player: Player, reason: string)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn("[ServerAuthority] BanRequest received invalid player")
		return
	end

	if typeof(reason) ~= "string" then
		reason = tostring(reason)
	end

	BanManager.BanPlayer(player, reason)
end

BanSignal:Connect(HandleBanRequest)

