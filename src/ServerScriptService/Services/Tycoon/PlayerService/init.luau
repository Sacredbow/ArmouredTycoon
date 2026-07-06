--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.ECS)
local FriendService = require(script.FriendService)
local StateManager = require(ServerScriptService.Utilities.StateManager)

local PlayerService = {}
PlayerService.__index = PlayerService

local TELEPORT_GRACE_DURATION = 2

function PlayerService.new()
	local self = setmetatable({}, PlayerService)
	self.PlayerStates = {} :: {[Player]: typeof(StateManager.new(nil :: any))}
	self.PlayerTycoons = {} :: { [Player]: any }
	self.PlayerSpawns = workspace:WaitForChild("PlayerSpawns")

	local friendService = FriendService.new(self)
	self.FriendService = friendService
	friendService:Init()
	return self
end

function PlayerService:_OnPlayerAdded(player: Player)
	-- Create a StateManager for this player
	self.PlayerStates[player] = StateManager.new(player)

	-- Attributes that still make sense on the player instance itself
	-- (these are read by the client or other non-service systems)
	player:SetAttribute("Multiplier", 1)
	player:SetAttribute("LastDamager", nil)
	player:SetAttribute("LastDamageTime", nil)
	player:SetAttribute("CanRebirth", false)

	player.CharacterAdded:Connect(function(character)
		self:_OnCharacterAdded(player, character)
	end)

        local character = player.Character
        if character then
                local humanoid  = character:FindFirstChild("Humanoid") :: Humanoid?
                if humanoid then
                        humanoid.Health = math.huge
                        ECS.createEntity({
                                Name = `{player.Name}:SpawnProtection`,
                                ScheduledTask = {
                                        delay = 10,
                                        elapsed = 0,
                                        callback = function()
                                                if player.Character and player.Character:FindFirstChild("Humanoid") then
                                                        local hum = player.Character:FindFirstChild("Humanoid") :: Humanoid
                                                        hum.Health = 100
                                                end
                                        end,
                                },
                        })
                end
        end
end

function PlayerService:_OnCharacterAdded(player: Player, character: Model)
	if self:OwnsTycoon(player) then return end
	self:_TeleportToSpawn(player, character)
	self:_ApplySpawnHighlight(character)
end

function PlayerService:AllowServerTeleport(player: Player, duration: number?)
	player:SetAttribute("AntiCheatTeleportGraceUntil", os.clock() + (duration or TELEPORT_GRACE_DURATION))
end

function PlayerService:_TeleportToSpawn(player: Player, character: Model)
	local spawns = self.PlayerSpawns:GetChildren()
	if #spawns == 0 then return end
	self:AllowServerTeleport(player)
	character:PivotTo(spawns[math.random(1, #spawns)].CFrame)
end

function PlayerService:_ApplySpawnHighlight(character: Model)
	local highlight = Instance.new("Highlight")
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.7
	highlight.Parent = character

        ECS.createEntity({
                Name = `{character.Name}:SpawnHighlightFade`,
                ScheduledTask = {
                        delay = 2,
                        elapsed = 0,
                        callback = function()
                                if not highlight.Parent then
                                        return
                                end

                local tween1 = TweenService:Create(highlight, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {FillTransparency = 1})
                local tween2 = TweenService:Create(highlight, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {OutlineTransparency = 1})
                tween1:Play()
                tween2:Play()
                                tween1.Completed:Once(function()
                                        highlight:Destroy()
                                end)
                        end,
                },
        })
end

function PlayerService:_OnPlayerRemoving(player: Player)
	self:CleanupPlayer(player)
end

--- Cleans up all player-side state. Called by TycoonService._OnPlayerRemoving.
--- @param player Player
function PlayerService:CleanupPlayer(player: Player)
	local state = self.PlayerStates[player]
	if state then
		state:Cleanup()
		self.PlayerStates[player] = nil
	end
	self.PlayerTycoons[player] = nil
	player:SetAttribute("CanRebirth", false)
end

function PlayerService:RegisterPlayerTycoon(player: Player, tycoon: any)
	self.PlayerTycoons[player] = tycoon
	player:SetAttribute("CanRebirth", false)
	print("[PlayerService] Registered tycoon for player:", player.Name)
	if self.TycoonService then
		self.TycoonService:RegisterOwner(player, tycoon)
	end
end

function PlayerService:Init()
	Players.PlayerAdded:Connect(function(player)
		self:_OnPlayerAdded(player)
	end)
end

-- X2
function PlayerService:HasX2(player: Player): boolean
	return self.PlayerStates[player]:HasState("X2")
end

function PlayerService:SetX2(player: Player, value: boolean)
	if value then
		self.PlayerStates[player]:SetState("X2")
	else
		self.PlayerStates[player]:RemoveState("X2")
	end
end

-- Electrified
function PlayerService:IsElectrified(player: Player): boolean
	return self.PlayerStates[player]:HasState("Electrified")
end

function PlayerService:SetElectrified(player: Player, value: boolean)
	if value then
		self.PlayerStates[player]:SetState("Electrified")
	else
		self.PlayerStates[player]:RemoveState("Electrified")
	end
end

-- FriendBoost
function PlayerService:HasFriendBoost(player: Player): boolean
	return self.PlayerStates[player]:HasState("FriendBoost")
end

function PlayerService:SetFriendBoost(player: Player, value: boolean)
	if value then
		self.PlayerStates[player]:SetState("FriendBoost")
	else
		self.PlayerStates[player]:RemoveState("FriendBoost")
	end
end

function PlayerService:GetFriendBoostMultiplier(player: Player): number
	if not self.FriendService then
		return 1
	end

	return self.FriendService:GetBoostMultiplier(player)
end

-- Rocket
function PlayerService:HasActivated(player: Player): boolean
	return self.PlayerStates[player]:HasState("RocketActivated")
end

function PlayerService:ActivateRocket(player: Player, value: boolean)
	if value then
		self.PlayerStates[player]:SetState("RocketActivated")
	else
		self.PlayerStates[player]:RemoveState("RocketActivated")
	end
end

function PlayerService:GetTycoon(player: Player): any?
	if self.TycoonService then
		return self.TycoonService:GetTycoonForPlayer(player)
	end

	return self.PlayerTycoons[player]
end

function PlayerService:OwnsTycoon(player: Player): boolean
	return self:GetTycoon(player) ~= nil
end

return PlayerService
