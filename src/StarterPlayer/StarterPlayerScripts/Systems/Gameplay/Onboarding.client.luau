--!strict
--[[
	@class OnboardingClient

	@desc
	Client-side onboarding helper. Draws guide beams from the player's
	character to tycoon doors, buttons, and the ATM as they follow the
	tutorial flow. Responds to Tutorial packets from the server.

	Beam system is keyed so individual beams can be removed without
	nuking all of them. Uses fresh Attachments + Beam instead of cloning
	the Arrow Beam model (which had WeldConstraints and physical parts
	that broke player physics).

	Message types are shared with the server via OnboardingDefinitions so
	the client and server can never drift on the tutorial control strings.
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const RuntimeSettings = require(ReplicatedStorage.Modules.SettingsManager.RuntimeSettings)
const Packets = require(ReplicatedStorage.Network.Packets)
const OnboardingDefinitions = require(ReplicatedStorage.Progression.Onboarding.OnboardingDefinitions)
const GameStore = require(script.Parent.Parent.Parent.UI.store.GameStore)

--// Constants

const Player = Players.LocalPlayer
const TycoonsFolder = workspace:WaitForChild("Tycoons")

const OnboardingStep = OnboardingDefinitions.STEP_BY_KEY

const BEAM_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 135, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 219)),
})
const BEAM_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.9, 0),
	NumberSequenceKeypoint.new(1, 1),
})
const BEAM_TEXTURE = "rbxassetid://6399401493"

--// Types

type TutorialData = {
	type: string,
	target: string?,
}

type BeamEntry = {
	att0: Attachment?,
	att1: Attachment?,
	beam: Beam?,
}

--// Runtime State

local ActiveBeams: { [string]: BeamEntry } = {}
local DoorBeamsEnabled = false
local ClaimedDoorKeys: { [string]: boolean } = {}
local LastTutorialMessage: string? = nil

local function ButtonDirectionsEnabled(): boolean
	return RuntimeSettings.GetBoolean("Allow Button Directions", true)
end

local buttonDirectionsEnabled = ButtonDirectionsEnabled()

--// Internal Utilities â€” Beam System

local function DestroyBeamEntry(Entry: BeamEntry)
	if Entry.beam then
		Entry.beam:Destroy()
	end
	if Entry.att0 then
		Entry.att0:Destroy()
	end
	if Entry.att1 then
		Entry.att1:Destroy()
	end
end

local function SetBeam(Start: BasePart, Target: BasePart, Key: string)
	if not buttonDirectionsEnabled then
		return
	end

	if ActiveBeams[Key] then
		DestroyBeamEntry(ActiveBeams[Key])
	end

	const Att0 = Instance.new("Attachment")
	Att0.Parent = Start

	const Att1 = Instance.new("Attachment")
	Att1.Parent = Target

	const Beam = Instance.new("Beam")
	Beam.Attachment0 = Att0
	Beam.Attachment1 = Att1
	Beam.Parent = Start
	Beam.Color = BEAM_COLOR
	Beam.Transparency = BEAM_TRANSPARENCY
	Beam.Width0 = 2
	Beam.Width1 = 2
	Beam.FaceCamera = true
	Beam.LightInfluence = 0
	Beam.LightEmission = 1
	Beam.Texture = BEAM_TEXTURE
	Beam.TextureMode = Enum.TextureMode.Static
	Beam.TextureSpeed = -2
	Beam.TextureLength = 5
	Beam.CurveSize0 = 20
	Beam.CurveSize1 = 20
	Beam.Segments = 500

	ActiveBeams[Key] = { att0 = Att0, att1 = Att1, beam = Beam }
end

local function DisplaceBeam(Key: string)
	const Entry = ActiveBeams[Key]
	if Entry then
		DestroyBeamEntry(Entry)
		ActiveBeams[Key] = nil
	end
end

local function DisplaceAllBeams()
	for _, Entry in ActiveBeams do
		DestroyBeamEntry(Entry)
	end
	table.clear(ActiveBeams)
end

--// Internal Utilities â€” Tycoon / Door Resolution

local function GetHRP(): BasePart?
	const Character = Player.Character
	if Character then
		return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

local function GetTycoonFromDescendant(Descendant: Instance): Instance?
	local Current: Instance? = Descendant
	while Current and Current.Parent ~= TycoonsFolder do
		Current = Current.Parent
	end

	return Current
end

local function GetDoorBeamKey(Door: BasePart): string
	const Tycoon = GetTycoonFromDescendant(Door)
	return if Tycoon then `tycoon_{Tycoon.Name}` else `tycoon_{Door:GetFullName()}`
end

local function GetDoorFromTycoonName(TycoonName: string): BasePart?
	const Tycoon = TycoonsFolder:FindFirstChild(TycoonName)
	const MainItems = Tycoon and Tycoon:FindFirstChild("MainItems")
	const OwnerDoor = MainItems and MainItems:FindFirstChild("OwnerDoor")
	const Door = OwnerDoor and OwnerDoor:FindFirstChild("Door")
	if Door and Door:IsA("BasePart") then
		return Door
	end

	return nil
end

local function ResolveTycoonPath(Path: string): BasePart?
	const Segments = string.split(Path, ":")
	const TycoonName = Segments[1]
	local Current: Instance? = TycoonsFolder:FindFirstChild(TycoonName)
	for Index = 2, #Segments do
		if not Current then
			return nil
		end
		Current = Current:FindFirstChild(Segments[Index])
	end

	if Current and Current:IsA("BasePart") then
		return Current
	end

	return nil
end

local function ResolveSignalTarget(Target: any?): BasePart?
	if typeof(Target) == "Instance" and Target:IsA("BasePart") then
		return Target
	elseif typeof(Target) == "string" then
		return ResolveTycoonPath(Target)
	end

	return nil
end

--// Internal Methods â€” Beam Controller

local function GetPlayerHRP()
	return GetHRP()
end

local function MarkTycoonClaimed(Target: any?)
	local Door = ResolveSignalTarget(Target)
	if not Door and typeof(Target) == "string" then
		Door = GetDoorFromTycoonName(Target)
	end

	if not Door then
		return
	end

	const Key = GetDoorBeamKey(Door)
	ClaimedDoorKeys[Key] = true
	DisplaceBeam(Key)
end

local function SetupTycoonBeams()
	if not DoorBeamsEnabled or not buttonDirectionsEnabled then
		return
	end

	for _, Tycoon in TycoonsFolder:GetChildren() do
		const MainItems = Tycoon:FindFirstChild("MainItems")
		if not MainItems then
			continue
		end

		const OwnerDoor = MainItems:FindFirstChild("OwnerDoor")
		if not OwnerDoor then
			continue
		end

		const Door = OwnerDoor:FindFirstChild("Door")
		if not Door or not Door:IsA("BasePart") then
			continue
		end

		const Key = GetDoorBeamKey(Door)
		if ClaimedDoorKeys[Key] then
			continue
		end

		const HRP = GetPlayerHRP()
		if HRP then
			SetBeam(HRP, Door, Key)
		end
	end
end

--// Bootstrap â€” Runtime Hooks

RuntimeSettings.Observe("Allow Button Directions", function()
	buttonDirectionsEnabled = ButtonDirectionsEnabled()
	if not buttonDirectionsEnabled then
		DisplaceAllBeams()
	else
		SetupTycoonBeams()
	end
end)

Player.CharacterAdded:Connect(function(Character)
	if not DoorBeamsEnabled or not buttonDirectionsEnabled then
		return
	end

	const HRP = Character:WaitForChild("HumanoidRootPart")
	for _, Tycoon in TycoonsFolder:GetChildren() do
		const MainItems = Tycoon:FindFirstChild("MainItems")
		if not MainItems then
			continue
		end
		const OwnerDoor = MainItems:FindFirstChild("OwnerDoor")
		if not OwnerDoor then
			continue
		end
		const Door = OwnerDoor:FindFirstChild("Door")
		if not Door or not Door:IsA("BasePart") then
			continue
		end
		const Key = GetDoorBeamKey(Door)
		if ClaimedDoorKeys[Key] then
			continue
		end
		SetBeam(HRP, Door, Key)
	end
end)

Packets.packets.Tutorial.listen(function(Data: TutorialData)
	const NewMessage = Data.type
	const Target = Data.target

	local TutorialMessage = if NewMessage == "TycoonAvailable"
		then "Find an unclaimed tycoon and touch its door to claim it."
		elseif NewMessage == OnboardingStep.ClaimComplete.Message
		then OnboardingStep.ClaimComplete.Message
		elseif NewMessage == OnboardingStep.PurchaseButton.Message
		then OnboardingStep.PurchaseButton.Message
		elseif NewMessage == OnboardingStep.ClaimMoney.Message
		then OnboardingStep.ClaimMoney.Message
		elseif NewMessage == OnboardingStep.Completed.Message
		then OnboardingStep.Completed.Message
		else nil
	if TutorialMessage and TutorialMessage ~= LastTutorialMessage then
		LastTutorialMessage = TutorialMessage
		GameStore.get():PushTutorialNotification(TutorialMessage)
		if NewMessage == OnboardingStep.Completed.Message then
			GameStore.get():PushTutorialNotification(TutorialMessage, 3)
		end
	end

	if NewMessage == "TycoonClaimed" then
		MarkTycoonClaimed(Target)
		return
	elseif NewMessage == "TycoonAvailable" then
		DoorBeamsEnabled = true
		local Door = ResolveSignalTarget(Target)
		if not Door and typeof(Target) == "string" then
			Door = GetDoorFromTycoonName(Target)
		end
		if Door then
			const Key = GetDoorBeamKey(Door)
			ClaimedDoorKeys[Key] = nil
			const HRP = GetPlayerHRP()
			if HRP then
				SetBeam(HRP, Door, Key)
			end
		end
		return
	elseif NewMessage == OnboardingStep.ClaimComplete.Message then
		DoorBeamsEnabled = false
		DisplaceAllBeams()
		return
	end

	if NewMessage == OnboardingStep.Completed.Message then
		DisplaceAllBeams()
		task.wait(3)
		script:Destroy()
		return
	end

	if NewMessage == OnboardingStep.PurchaseButton.Message then
		if not buttonDirectionsEnabled then
			return
		end
		const TargetPart = ResolveSignalTarget(Target)
		if not TargetPart then
			warn("[Onboarding] Target not found for button beam")
			return
		end
		DisplaceAllBeams()
		task.wait()
		const HRP = GetPlayerHRP()
		if HRP then
			SetBeam(HRP, TargetPart, "tutorial_button")
		end
	elseif NewMessage == OnboardingStep.ClaimMoney.Message then
		if not buttonDirectionsEnabled then
			return
		end
		const TargetPart = ResolveSignalTarget(Target)
		if not TargetPart then
			warn("[Onboarding] Target not found for ATM beam")
			return
		end
		DisplaceAllBeams()
		task.wait()
		const HRP = GetPlayerHRP()
		if HRP then
			SetBeam(HRP, TargetPart, "tutorial_atm")
		end
	end
end)
