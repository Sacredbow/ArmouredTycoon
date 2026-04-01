local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local IsServer = RunService:IsServer()

local RootDirectory = if IsServer
	then ServerScriptService
	else Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Controllers")

local function RequireModule(Module: Script)
	if not Module:IsA("ModuleScript") then
		return
	end

	local success, result = pcall(require, Module)

	if success and typeof(result) == "table" then
		if result.OnStart then
			task.spawn(result.OnStart)
		end
	end
end

return function()
	for _, Module in RootDirectory:GetDescendants() do
		RequireModule(Module)
	end
	if not IsServer then
		RootDirectory.DescendantAdded:Connect(function(Module)
			RequireModule(Module)
		end)
	end
end
