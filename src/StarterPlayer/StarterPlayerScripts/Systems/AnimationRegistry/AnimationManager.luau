--!strict
--[[
	@class AnimationManager

	@desc
	Client-side animation controller for NPC models.
	Loads and manages animation tracks on NPC Humanoids.

	This replaces the previous server-side animation loading in
	ProductionSystem._SetupAmmoArea, moving animation playback
	to the client where it belongs.

	Usage:
	```lua
	local AnimationManager = require(script.Parent.AnimationManager)
	AnimationManager:Start()
	-- Animations are automatically found and applied
```

	Architecture:
	- Watches for new NPC models in workspace.NPCs
	- Scans for NPC models within tycoon Stages
	- Each NPC with a Humanoid gets its idle animation loaded
	- Animations are stored in ReplicatedStorage.Assets.Animations
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Constants

const Animations = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations")
const NPCFolder = workspace:WaitForChild("NPCs")
const TycoonFolder = workspace:WaitForChild("Tycoons")
const AnimationMap = require(script.Parent.AnimationMap)

--// Types

local AnimationManager = {}
AnimationManager.__index = AnimationManager

type AnimationEntry = {
	Humanoid: Humanoid,
	Tracks: { AnimationTrack },
	Cleanup: () -> (),
}

type AnimationManager =  {
	GetAnimation: (self: AnimationManager, NPCName: string) -> Animation?,
	RegisterNPC: (self: AnimationManager, NPCModel: Model) -> (),
	UnregisterNPC: (self: AnimationManager, NPCModel: Model) -> (),
	ScanNPCFolder: (self: AnimationManager) -> (),
	ScanTycoonNPCs: (self: AnimationManager) -> (),
	Start: (self: AnimationManager) -> ()
}

type InternalData = {
	RegisteredNPCs: { [Instance]: AnimationEntry },
	Started: boolean,
	Destroyed: boolean,
	NPCAddedConnection: RBXScriptConnection?,
	NPCRemovedConnection: RBXScriptConnection?,
}

export type InternalRegistry = typeof(setmetatable({} :: InternalData, AnimationManager))
--// Module

function AnimationManager.new(): InternalRegistry
	local self = setmetatable({}, AnimationManager) :: InternalRegistry

	self.RegisteredNPCs = {}
	self.Started = false
	self.Destroyed = false
    self.NPCAddedConnection = nil :: RBXScriptConnection?
    self.NPCRemovedConnection = nil :: RBXScriptConnection?

    return self :: InternalRegistry
end
function AnimationManager:GetAnimation(NPCName: string): Animation?

	local AnimationName = AnimationMap[NPCName]
	if not AnimationName then
		return nil
	end

	local AnimationObject = Animations:FindFirstChild(AnimationName)
	if AnimationObject and AnimationObject:IsA("Animation") then
		return AnimationObject
	end

	return nil
end

--// NPC Registration

function AnimationManager:RegisterNPC(NPCModel: Model)
	if self.RegisteredNPCs[NPCModel] then
		return
	end

	local Humanoid = NPCModel:FindFirstChildOfClass("Humanoid") :: Humanoid
	if not Humanoid then
		return
	end

	local AnimationObject = self:GetAnimation(NPCModel.Name)
	if not AnimationObject then
		return
	end

	-- Ensure Animator exists on the Humanoid
	local Animator = Humanoid:FindFirstChildOfClass("Animator") :: Animator
	if not Animator then
		warn(`Animator was not found in {NPCModel.Name}`)
		return
	end

	-- Load and play the animation
	local Track = Animator:LoadAnimation(AnimationObject)
	Track.Looped = true
	Track:Play()

	-- Store for cleanup
	self.RegisteredNPCs[NPCModel] = {
		Humanoid = Humanoid,
		Tracks = { Track },
		Cleanup = function()
			Track:Stop()
			Track:Destroy()
		end,
	}
end

function AnimationManager:UnregisterNPC(NPCModel: Model)
	local Entry = self.RegisteredNPCs[NPCModel]
	if not Entry then
		return
	end

	Entry.Cleanup()
	self.RegisteredNPCs[NPCModel] = nil
end

--// Scanning

function AnimationManager:ScanNPCFolder()
	for _, NPCInstance in NPCFolder:GetChildren() do
		if NPCInstance:IsA("Model") and NPCInstance:FindFirstChildOfClass("Humanoid") then
			self:RegisterNPC(NPCInstance)
		end
	end
end

function AnimationManager:ScanTycoonNPCs()
	for _, TycoonModel in TycoonFolder:GetChildren() do
		if not TycoonModel:IsA("Model") then
			continue
		end

		-- Scan all descendant NPC models within the tycoon
		for _, Descendant in TycoonModel:GetDescendants() do
			if
				Descendant:IsA("Model")
				and Descendant:FindFirstChild("Humanoid")
				and not Descendant:FindFirstChildOfClass("Tool")
			then
				self:RegisterNPC(Descendant)
			end
		end
	end
end

--// Lifecycle

function AnimationManager:Start()
	if self.Started then
		return
	end

	self.Started = true

	-- Scan all existing NPCs
	self:ScanNPCFolder()
	self:ScanTycoonNPCs()

	-- Watch for new NPCs being added to the NPC folder
	self.NPCAddedConnection = NPCFolder.ChildAdded:Connect(function(Child)
		if Child:IsA("Model") and Child:FindFirstChildOfClass("Humanoid") then
			self:RegisterNPC(Child)
		end
	end)

	-- Watch for NPCs being removed
	self.NPCRemovedConnection = NPCFolder.ChildRemoved:Connect(function(Child)
		if Child:IsA("Model") then
			self:UnregisterNPC(Child)
		end
	end)
end

function AnimationManager:Destroy() 
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Started = false

	for NPCModel, _ in self.RegisteredNPCs do
		self:UnregisterNPC(NPCModel)
	end

	

	if self.NPCAddedConnection ~= nil then
		self.NPCAddedConnection:Disconnect()
		self.NPCAddedConnection = nil
	end

	if self.NPCRemovedConnection ~= nil then
		self.NPCRemovedConnection:Disconnect()
		self.NPCRemovedConnection = nil
	end
end

return AnimationManager
