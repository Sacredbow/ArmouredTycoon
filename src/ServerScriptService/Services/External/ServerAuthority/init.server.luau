local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Observers = require(ReplicatedStorage.Packages.Observers)
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Signal = require(ReplicatedStorage.Packages.signal)
local BanSignal = Signal.get("ServerBanRequest")
local BanManager = require(script.Methods.BanManager)

local AntiCheatEntitiesByPlayer: { [Player]: number } = {}

local function RegisterCharacter(player: Player, character: Model)
	local previousEntity = AntiCheatEntitiesByPlayer[player]
	if previousEntity then
		ECS.deleteEntity(previousEntity)
		AntiCheatEntitiesByPlayer[player] = nil
	end

	local humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local now = os.clock()

	AntiCheatEntitiesByPlayer[player] = ECS.createEntity({
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

Observers.observePlayer(function(player: Player)
	return function()
		local entity = AntiCheatEntitiesByPlayer[player]
		if entity then
			ECS.deleteEntity(entity)
			AntiCheatEntitiesByPlayer[player] = nil
		end
	end
end)

Observers.observeCharacter(function(player: Player, character: Model)
	RegisterCharacter(player, character)
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

