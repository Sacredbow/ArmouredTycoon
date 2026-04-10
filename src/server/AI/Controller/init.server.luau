--!strict

local NPCData = require(script.Core.NPCData)
type NPCController = NPCData.NPCController

local NPCs = workspace:WaitForChild("NPCs")

type NPCControllerMap = {
	[string]: NPCController?,
}

local NPCController: NPCControllerMap = {}

local function initializeNPCControllers(npcFolder: Folder, controllerMap: NPCControllerMap)
	for _, instance: Instance in npcFolder:GetChildren() do
		if instance:IsA("Model") and instance:FindFirstChildOfClass("Humanoid") then
			local npc: Model = instance
			controllerMap[npc.Name] = NPCData.new(npc)
		else
			warn(`[AIController] Skipping "{instance.Name}" because it is not a valid NPC model`)
		end
	end
end

initializeNPCControllers(NPCs, NPCController)

NPCs.ChildAdded:Connect(function(instance: Instance)
	if not instance:IsA("Model") or not instance:FindFirstChildOfClass("Humanoid") then
		return
	end

	local npc: Model = instance

	if NPCController[npc.Name] ~= nil then
		return
	end

	NPCController[npc.Name] = NPCData.new(npc) 
end)
