local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Janitor = require(ReplicatedStorage.Packages.janitor)

local janitor = Janitor.new()

janitor:Add(script.Destroying:Connect(function()
	janitor:Destroy()
end), "Disconnect", "Destroying")

local function packetsNamespaceReady(): boolean
	local storage = ReplicatedStorage:FindFirstChild("BytenetStorage")
	local namespaceValue = storage and storage:FindFirstChild("ArmouredTycoon")
	return namespaceValue ~= nil and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= ""
end

janitor:Add(task.spawn(function()
	local Packets = nil
	while not Packets do
		if packetsNamespaceReady() then
			local ok, result = pcall(function()
				return require(ReplicatedStorage.Network.Packets)
			end)
			if ok then
				Packets = result
			else
				task.wait(0.5)
			end
		else
			task.wait(0.5)
		end
	end

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
			warn(`[NPCBubble] Failed to display bubble: {err}`)
		end
	end), true, "NPCSpeech")
end), true, "StartupThread")
