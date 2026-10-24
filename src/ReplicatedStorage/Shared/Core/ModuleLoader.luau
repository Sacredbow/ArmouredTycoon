local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local IsServer = RunService:IsServer()

local function getClientModuleRoot(): Instance?
	local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	return playerScripts:FindFirstChild("Client")
end

local RootDirectory = if IsServer then ServerScriptService else getClientModuleRoot()

local function startModule(module: Script)
	if not module:IsA("ModuleScript") then
		return
	end

	local success, result = pcall(require, module)

	if success and typeof(result) == "table" then
		if result.OnStart then
			task.defer(result.OnStart)
		end
	end
end

return function()
	if not RootDirectory then
		warn("[ModuleLoader] No client module root was found; skipping controller auto-start")
		return
	end

	for _, module in RootDirectory:GetDescendants() do
		startModule(module)
	end
	if not IsServer then
		RootDirectory.DescendantAdded:Connect(function(module)
			startModule(module)
		end)
	end
end
