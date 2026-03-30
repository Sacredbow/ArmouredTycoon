--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local FriendService = require(script.FriendService)
local StateManager = require(ServerScriptService.Utilities.StateManager)

local PlayerService = {}
PlayerService.__index = PlayerService

function PlayerService.new()
	local self = setmetatable({}, PlayerService)
	self.PlayerStates = {} :: {[Player]: typeof(StateManager.new(nil :: any))}
	self.PlayerTycoons = {}
	self.PlayerSpawns = workspace:WaitForChild("PlayerSpawns")

	local friendService = FriendService.new(self)
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

	local hasTycoon = Instance.new("BoolValue")
	hasTycoon.Name = "hasTycoon"
	hasTycoon.Value = false
	hasTycoon.Parent = player

	player.CharacterAdded:Connect(function(character)
		self:_OnCharacterAdded(player, character)
	end)

	-- Spawn protection
	task.spawn(function()
		local character = player.Character
		if not character then return end
		local humanoid  = character:FindFirstChild("Humanoid") :: Humanoid
		if not humanoid then return end
		humanoid.Health = math.huge
		task.wait(10)
		-- Re-check everything is still valid after the wait
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			local hum = player.Character:FindFirstChild("Humanoid") :: Humanoid
			hum.Health = 100
		end
	end)
end

function PlayerService:_OnCharacterAdded(player: Player, character: Model)
	local hasTycoon = player:FindFirstChild("hasTycoon")
	if hasTycoon and (hasTycoon :: BoolValue).Value then return end
	self:_TeleportToSpawn(character)
	self:_ApplySpawnHighlight(character)
end

function PlayerService:_TeleportToSpawn(character: Model)
	local spawns = self.PlayerSpawns:GetChildren()
	if #spawns == 0 then return end
	character:PivotTo(spawns[math.random(1, #spawns)].CFrame)
end

function PlayerService:_ApplySpawnHighlight(character: Model)
	local highlight = Instance.new("Highlight")
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.7
	highlight.Parent = character

	task.delay(2, function()
		local tween1 = TweenService:Create(highlight, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {FillTransparency = 1})
		local tween2 = TweenService:Create(highlight, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {OutlineTransparency = 1})
		tween1:Play()
		tween2:Play()
		tween1.Completed:Wait()
		highlight:Destroy()
	end)
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
	self.PlayerTycoons[player.UserId] = nil
end

function PlayerService:RegisterPlayerTycoon(player: Player, tycoon: any)
	self.PlayerTycoons[player.UserId] = tycoon
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
		self.PlayerStates[player]:RemoveState(2)
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

return PlayerService