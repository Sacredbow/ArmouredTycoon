local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.ECS)
local Packets = require(ReplicatedStorage.Network.Packets)

local FriendService = {}
FriendService.__index = FriendService

function FriendService.new(playerService)
	local self = setmetatable({}, FriendService)
	self.PlayerService = playerService
	self.ActiveBoosts = {}
	self.FriendPairs = {} 
	return self
end

function FriendService:CheckFriendBoost(player: Player)
	if not player or not player.Parent then 
		return
	end

	local friendsInGame = {}

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Parent then
			local success, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)

			if success and isFriend then
				table.insert(friendsInGame, other)
			end
		end
	end

	
	local friendCount = #friendsInGame
	self.ActiveBoosts[player] = friendCount
	self.FriendPairs[player] = friendsInGame

	if friendCount > 0 then
		local FriendBoostMulti = 0.10
		local MultiCalc = friendCount * FriendBoostMulti
		local TextCalc = MultiCalc * 100

	
		self.PlayerService:SetFriendBoost(player, true)
Packets.packets.FriendBoost.sendTo({ ["type"] = "Connected", percent = TextCalc }, player)
	else
		
		self.PlayerService:SetFriendBoost(player, false)
		Packets.packets.FriendBoost.sendTo({ ["type"] = "Connected", percent = 0 }, player)
	end
end

function FriendService:UpdateAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		self:CheckFriendBoost(player)
	end
end

function FriendService:GetFriendCount(player: Player): number
	return self.ActiveBoosts[player] or 0
end

function FriendService:GetBoostMultiplier(player: Player): number
	return 1 + (self:GetFriendCount(player) * 0.10)
end

function FriendService:OnPlayerLeaving(leavingPlayer: Player)
	
	self.ActiveBoosts[leavingPlayer] = nil
	self.FriendPairs[leavingPlayer] = nil

	
	for player, friends in pairs(self.FriendPairs) do
		if player ~= leavingPlayer and player.Parent then
			for i, friend in ipairs(friends) do
				if friend == leavingPlayer then
					
					table.remove(friends, i)

					local newCount = #friends
					self.ActiveBoosts[player] = newCount

					if newCount > 0 then
						
						local FriendBoostMulti = 0.10
						local MultiCalc = newCount * FriendBoostMulti
						local TextCalc = MultiCalc * 100

						Packets.packets.FriendBoost.sendTo({ ["type"] = "Disconnected", percent = TextCalc }, player)
						
					else
						self.PlayerService:SetFriendBoost(player, false)
						Packets.packets.FriendBoost.sendTo({ ["type"] = "Disconnected", percent = 0 }, player)
					end
					break
				end
			end
		end
	end
end

function FriendService:Init()
        Players.PlayerAdded:Connect(function(player)
                ECS.createEntity({
                        Name = `{player.Name}:FriendBoostCheck`,
                        ScheduledTask = {
                                delay = 2,
                                elapsed = 0,
                                callback = function()
                                        if player and player.Parent then
                                                self:CheckFriendBoost(player)

                                                ECS.createEntity({
                                                        Name = `{player.Name}:FriendBoostRefresh`,
                                                        ScheduledTask = {
                                                                delay = 0.5,
                                                                elapsed = 0,
                                                                callback = function()
                                                                        self:UpdateAllPlayers()
                                                                end,
                                                        },
                                                })
                                        end
                                end,
                        },
                })
        end)

	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerLeaving(player)
	end)
end

return FriendService

