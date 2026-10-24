--!strict

const PromptService = game:GetService("ProximityPromptService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Janitor = require(ReplicatedStorage.Packages.janitor)
const PromptEffect = require(script.Modules.PromptEffect)
const PromptFolder = script.Prompts

const Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
const ActiveModules: { [string]: any } = {}
const ActivePrompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" })
const LifecycleJanitor = Janitor.new()

local function IsCustom(Prompt: ProximityPrompt): boolean
	if Prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return false
	end

	const Configuration = Prompt:FindFirstChild("CustomPromptConf")
	const CustomPrompt = Configuration and Configuration:FindFirstChild("CustomPrompt")
	return CustomPrompt ~= nil and CustomPrompt:IsA("BoolValue") and CustomPrompt.Value == true
end

local function GetConfiguration(Prompt: ProximityPrompt): Instance?
	const Configuration = Prompt:FindFirstChild("CustomPromptConf")
	return Configuration
end

local function GetPromptModule(Prompt: ProximityPrompt): any?
	const Configuration = GetConfiguration(Prompt)
	const PromptName = Configuration and Configuration:FindFirstChild("PromptName")
	if not PromptName or not PromptName:IsA("StringValue") then
		return nil
	end

	const ModuleScript = PromptFolder:FindFirstChild(PromptName.Value)
	if not ModuleScript or not ModuleScript:IsA("ModuleScript") then
		warn(`[CustomPrompt] Prompt module not found: {PromptName.Value}`)
		return nil
	end

	local Module = ActiveModules[PromptName.Value]
	if not Module then
		Module = require(ModuleScript)
		ActiveModules[PromptName.Value] = Module
	end
	return Module
end

local function Handle(Prompt: ProximityPrompt, MethodName: string, InputType: Enum.ProximityPromptInputType)
	if not IsCustom(Prompt) then
		return
	end

	const Module = GetPromptModule(Prompt)
	const Handler = Module and Module[MethodName]
	if type(Handler) == "function" then
		Handler(Module, Prompt, InputType, Player)
	end
end

local function DestroyPromptEffects(Prompt: ProximityPrompt)
	if not IsCustom(Prompt) then
		ActivePrompts[Prompt] = nil
		return
	end

	const Configuration = GetConfiguration(Prompt)
	const Parent = Prompt.Parent
	if Configuration and Parent and Parent:IsA("BasePart") then
		const Beam = Configuration:FindFirstChild("Beam")
		if Beam and Beam:IsA("BoolValue") and Beam.Value then
			const Root = Character and Character:FindFirstChild("HumanoidRootPart")
			PromptEffect:DestroyBeam(Parent, if Root and Root:IsA("BasePart") then Root else nil)
		end
		const Highlight = Configuration:FindFirstChild("Highlight")
		if Highlight and Highlight:IsA("BoolValue") and Highlight.Value then
			PromptEffect:DestroyHighlight(Parent)
		end
	end
	ActivePrompts[Prompt] = nil
end

local function CreatePromptEffects(Prompt: ProximityPrompt)
	if not IsCustom(Prompt) then
		return
	end

	const Configuration = GetConfiguration(Prompt)
	const Parent = Prompt.Parent
	if not Configuration or not Parent or not Parent:IsA("BasePart") then
		return
	end

	const Root = Character and Character:FindFirstChild("HumanoidRootPart")
	const Beam = Configuration:FindFirstChild("Beam")
	if Beam and Beam:IsA("BoolValue") and Beam.Value and Root and Root:IsA("BasePart") then
		PromptEffect:CreateBeam(Parent, Root, Configuration)
	end
	const Highlight = Configuration:FindFirstChild("Highlight")
	if Highlight and Highlight:IsA("BoolValue") and Highlight.Value then
		PromptEffect:CreateHighlight(Parent, Configuration)
	end
	ActivePrompts[Prompt] = true
end

LifecycleJanitor:Add(Player.CharacterAdded:Connect(function(NewCharacter: Model)
	Character = NewCharacter
	for Prompt in ActivePrompts do
		DestroyPromptEffects(Prompt)
		CreatePromptEffects(Prompt)
	end
end), "Disconnect", "CharacterAdded")

LifecycleJanitor:Add(PromptService.PromptShown:Connect(function(Prompt: ProximityPrompt, InputType: Enum.ProximityPromptInputType)
	DestroyPromptEffects(Prompt)
	CreatePromptEffects(Prompt)
	Handle(Prompt, "onShown", InputType)
end), "Disconnect", "PromptShown")

LifecycleJanitor:Add(PromptService.PromptHidden:Connect(function(Prompt: ProximityPrompt, InputType: Enum.ProximityPromptInputType)
	DestroyPromptEffects(Prompt)
	Handle(Prompt, "onHidden", InputType)
end), "Disconnect", "PromptHidden")

LifecycleJanitor:Add(PromptService.PromptTriggered:Connect(function(Prompt: ProximityPrompt, InputType: Enum.ProximityPromptInputType)
	Handle(Prompt, "onTriggered", InputType)
end), "Disconnect", "PromptTriggered")

LifecycleJanitor:Add(PromptService.PromptButtonHoldBegan:Connect(function(Prompt: ProximityPrompt, InputType: Enum.ProximityPromptInputType)
	Handle(Prompt, "onHoldStart", InputType)
end), "Disconnect", "PromptButtonHoldBegan")

LifecycleJanitor:Add(PromptService.PromptButtonHoldEnded:Connect(function(Prompt: ProximityPrompt, InputType: Enum.ProximityPromptInputType)
	Handle(Prompt, "onHoldEnd", InputType)
end), "Disconnect", "PromptButtonHoldEnded")

LifecycleJanitor:Add(script.Destroying:Connect(function()
	for Prompt in ActivePrompts do
		DestroyPromptEffects(Prompt)
	end
	LifecycleJanitor:Destroy()
end), "Disconnect", "Destroying")

const ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Name = "CustomPrompts"
ScreenGui.Parent = Player:WaitForChild("PlayerGui")
