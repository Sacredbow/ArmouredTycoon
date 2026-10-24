--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)

local DefaultCooldown = 2
local LastSent: { [Player]: { [string]: number } } = setmetatable({}, { __mode = "k" })

return function(Player: Player?, Type: string, Message: string, Cooldown: number?)
	if not Player or not Player.Parent then
		return
	end

	local Now = os.clock()
	local Messages = LastSent[Player]
	if not Messages then
		Messages = {}
		LastSent[Player] = Messages
	end

	if Now - (Messages[Message] or 0) < (Cooldown or DefaultCooldown) then
		return
	end

	Messages[Message] = Now
	Packets.packets.Notification.sendTo({
		["type"] = Type,
		message = Message,
	}, Player)
end
