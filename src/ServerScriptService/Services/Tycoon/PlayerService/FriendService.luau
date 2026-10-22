--!strict
--[[
	FriendBoost is ECS-owned player state. This module performs the Roblox
	friendship query and writes the resulting plain data to player entities.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.ECS)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Packets = require(ReplicatedStorage.Network.Packets)

local FriendService = {}
local initialized = false

type FriendBoostState = {
	count: number,
	friendUserIds: { [number]: boolean },
}

local function getEntity(player: Player): number?
	for entity, playerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if playerRef == player then
			return entity
		end
	end
	return nil
end

local function getBoostState(player: Player): (number?, FriendBoostState?)
	local entity = getEntity(player)
	if not entity then
		return nil, nil
	end

	local state = ECS.world:get(entity, ECS.Components.FriendBoost) :: FriendBoostState?
	if not state then
		state = { count = 0, friendUserIds = {} }
		ECS.world:set(entity, ECS.Components.FriendBoost, state)
	end
	return entity, state
end


local function publish(player: Player, state: FriendBoostState, eventType: string)
	Packets.packets.FriendBoost.sendTo({
		["type"] = eventType,
		percent = state.count * 10,
	}, player)
end

function FriendService.CheckFriendBoost(player: Player)
	if not player.Parent then
		return
	end

	local entity, state = getBoostState(player)
	if not entity or not state then
		return
	end

	local friendUserIds: { [number]: boolean } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Parent then
			local success, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if success and isFriend then
				friendUserIds[other.UserId] = true
			end
		end
	end

	state.friendUserIds = friendUserIds
	state.count = 0
	for _ in friendUserIds do
		state.count += 1
	end
	ECS.world:set(entity, ECS.Components.FriendBoost, state)
	publish(player, state, "Connected")
end

function FriendService.UpdateAllPlayers()
	for _, player in Players:GetPlayers() do
		FriendService.CheckFriendBoost(player)
	end
end

function FriendService.GetFriendCount(player: Player): number
	local _, state = getBoostState(player)
	return if state then state.count else 0
end

function FriendService.GetBoostMultiplier(player: Player): number
	return 1 + FriendService.GetFriendCount(player) * 0.10
end

function FriendService.OnPlayerLeaving(leavingPlayer: Player)
	for entity, playerRef, state in ECS.world:query(ECS.Components.PlayerRef, ECS.Components.FriendBoost) do
		if playerRef ~= leavingPlayer and typeof(playerRef) == "Instance" and playerRef:IsA("Player") and playerRef.Parent then
			local friendState = state :: FriendBoostState
			if friendState.friendUserIds[leavingPlayer.UserId] then
				friendState.friendUserIds[leavingPlayer.UserId] = nil
				friendState.count = math.max(0, friendState.count - 1)
				ECS.world:set(entity, ECS.Components.FriendBoost, friendState)
				publish(playerRef, friendState, "Disconnected")
			end
		end
	end
end

function FriendService.RunInitialCheck(player: Player)
	if not player.Parent then
		return
	end

	FriendService.CheckFriendBoost(player)
	ECS.createEntity({
		Name = "FriendBoostRefresh:" .. player.Name,
		ScheduledTask = {
			delay = 0.5,
			elapsed = 0,
			kind = "FriendBoostRefresh",
		},
	})
end

function FriendService.RefreshActive()
	FriendService.UpdateAllPlayers()
end

function FriendService.Init()
	if initialized then
		return
	end
	initialized = true

	Observers.observePlayer(function(player: Player)
		ECS.createEntity({
			Name = "FriendBoostCheck:" .. player.Name,
			ScheduledTask = {
				delay = 2,
				elapsed = 0,
				kind = "FriendBoostInitial",
				player = player,
			},
		})

		return function()
			FriendService.OnPlayerLeaving(player)
		end
	end)
end

return FriendService