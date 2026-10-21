local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Janitor = require(ReplicatedStorage.Packages.janitor)
local PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)

local janitor = Janitor.new()

janitor:Add(script.Destroying:Connect(function()
	janitor:Destroy()
end), "Disconnect", "Destroying")

janitor:Add(task.spawn(function()
	local Packets = PacketBootstrap.Get()
	janitor:Add(Packets.packets.NPCSpeech.listen(function(payload)
		local adornee = payload.adornee
		local message = payload.message
		if typeof(message) ~= "string" or message == "" then
			return
		end

		if typeof(adornee) ~= "Instance" or not adornee:IsDescendantOf(workspace) then
			return
		end

		local success, err = pcall(function()
			TextChatService:DisplayBubble(adornee, message)
		end)

		if not success then
			warn("[NPCBubble] Failed to display bubble:", err)
		end
	end), true, "NPCSpeech")
end), true, "StartupThread")
