local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local bubbleRemote = remotesFolder:WaitForChild("NPCBubbleSpeech")

bubbleRemote.OnClientEvent:Connect(function(adornee: Instance, message: string)
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
		warn(`[NPCBubble] Failed to display bubble: {err}`)
	end
end)
