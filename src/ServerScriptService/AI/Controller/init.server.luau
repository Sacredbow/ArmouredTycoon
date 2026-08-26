--!strict
--[[
	@class AIController

	@desc
	Bootstraps NPC controllers for every NPC model in Workspace.NPCs.
	Creates NPCData controllers on startup and watches for new NPC
	models added at runtime (e.g. respawns) to keep the map in sync.
]]

--// Services

const Workspace = game:GetService("Workspace")

--// Modules

const NPCData = require(script.Core.NPCData)

--// Types

type NPCController = NPCData.NPCController

type NPCControllerMap = {
	[string]: NPCController?,
}

--// Constants

const NPCs = Workspace:WaitForChild("NPCs")

--// Module

const NPCController: NPCControllerMap = {}

--// Internal Utilities

local function InitializeNPCControllers(NpcFolder: Folder, ControllerMap: NPCControllerMap)
	for _, Instance: Instance in NpcFolder:GetChildren() do
		if Instance:IsA("Model") and Instance:FindFirstChildOfClass("Humanoid") then
			const Npc: Model = Instance
			ControllerMap[Npc.Name] = NPCData.new(Npc)
		else
			warn(`[AIController] Skipping "{Instance.Name}" because it is not a valid NPC model`)
		end
	end
end

--// Bootstrap

InitializeNPCControllers(NPCs, NPCController)

NPCs.ChildAdded:Connect(function(Instance: Instance)
	if not Instance:IsA("Model") or not Instance:FindFirstChildOfClass("Humanoid") then
		return
	end

	const Npc: Model = Instance
	if NPCController[Npc.Name] ~= nil then
		return
	end

	NPCController[Npc.Name] = NPCData.new(Npc)
end)
