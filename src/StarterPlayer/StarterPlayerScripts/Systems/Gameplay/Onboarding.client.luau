--[[

Introduction into the game once you start

]]

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeSettings = require(ReplicatedStorage.Modules.SettingsManager.RuntimeSettings)
local TycoonsFolder = workspace:WaitForChild("Tycoons")
local NetworkFolder = ReplicatedStorage:WaitForChild("Network")
local TutorialSignal = NetworkFolder:WaitForChild("TutorialSignal") :: RemoteEvent

type TutorialKind = "TycoonClaimed" | "TycoonAvailable" | "Perfect!" | "Now purchase your first button!" | "Claim your money" | "Congrats! Tutorial Completed."

local PROTOCOL_VERSION = 1

local function getKindFromActionId(actionId: number): TutorialKind?
	if actionId == 1 then
		return "TycoonClaimed"
	elseif actionId == 2 then
		return "TycoonAvailable"
	elseif actionId == 3 then
		return "Perfect!"
	elseif actionId == 4 then
		return "Now purchase your first button!"
	elseif actionId == 5 then
		return "Claim your money"
	elseif actionId == 6 then
		return "Congrats! Tutorial Completed."
	end

	return nil
end

local function decodeTutorialMessage(message: any): TutorialKind?
	if typeof(message) == "string" then
		local actionIdByName: { [string]: TutorialKind } = {
			TycoonClaimed = "TycoonClaimed",
			TycoonAvailable = "TycoonAvailable",
			["Perfect!"] = "Perfect!",
			["Now purchase your first button!"] = "Now purchase your first button!",
			["Claim your money"] = "Claim your money",
			["Congrats! Tutorial Completed."] = "Congrats! Tutorial Completed.",
		}

		return actionIdByName[message]
	end

	if typeof(message) ~= "number" then
		return nil
	end

	local version = bit32.rshift(message, 8)
	if version ~= PROTOCOL_VERSION then
		return nil
	end

	return getKindFromActionId(bit32.band(message, 0xff))
end

---------------------------------------------------------------------------
-- Beam system (keyed so we can remove specific beams without nuking all)
-- Uses fresh Attachments + Beam instead of cloning the Arrow Beam model,
-- which had WeldConstraints and physical parts that broke player physics.
---------------------------------------------------------------------------

local activeBeams: { [string]: { att0: Attachment, att1: Attachment, beam: Beam } } = {}
local doorBeamsEnabled = false
local claimedDoorKeys: { [string]: boolean } = {}

local function allowButtonDirections(): boolean
	return RuntimeSettings.GetBoolean('Allow Button Directions', true)
end

local buttonDirectionsEnabled = allowButtonDirections()

local function setBeam(start: BasePart, target: BasePart, key: string)
	if not buttonDirectionsEnabled then
		return
	end

	-- Remove old beam with the same key if it exists
	if activeBeams[key] then
		if activeBeams[key].beam then activeBeams[key].beam:Destroy() end
		if activeBeams[key].att0 then activeBeams[key].att0:Destroy() end
		if activeBeams[key].att1 then activeBeams[key].att1:Destroy() end
	end

	local att0 = Instance.new("Attachment")
	att0.Parent = start

	local att1 = Instance.new("Attachment")
	att1.Parent = target

	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Parent = start
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 135, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 219)),
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.9, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Width0 = 2
	beam.Width1 = 2
	beam.FaceCamera = true
	beam.LightInfluence = 0
	beam.LightEmission = 1
	beam.Texture = "rbxassetid://6399401493"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureSpeed = -2
	beam.TextureLength = 5
	beam.CurveSize0 = 20
	beam.CurveSize1 = 20
	beam.Segments = 500

	activeBeams[key] = { att0 = att0, att1 = att1, beam = beam }
end

local function DisplaceBeam(key: string)
	if activeBeams[key] then
		if activeBeams[key].beam then activeBeams[key].beam:Destroy() end
		if activeBeams[key].att0 then activeBeams[key].att0:Destroy() end
		if activeBeams[key].att1 then activeBeams[key].att1:Destroy() end
		activeBeams[key] = nil
	end
end

local function DisplaceAllBeams()
	for key, entry in activeBeams do
		if entry.beam then entry.beam:Destroy() end
		if entry.att0 then entry.att0:Destroy() end
		if entry.att1 then entry.att1:Destroy() end
	end
	table.clear(activeBeams)
end

---------------------------------------------------------------------------
-- Tycoon door beams (set up once, not inside the event handler)
---------------------------------------------------------------------------

local function getHRP(): BasePart?
	local character = Player.Character
	if character then
		return character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

local function getTycoonFromDescendant(descendant: Instance): Instance?
	local current: Instance? = descendant
	while current and current.Parent ~= TycoonsFolder do
		current = current.Parent
	end

	return current
end

local function getDoorBeamKey(door: BasePart): string
	local tycoon = getTycoonFromDescendant(door)
	return if tycoon then `tycoon_{tycoon.Name}` else `tycoon_{door:GetFullName()}`
end

local function getDoorFromTycoonName(tycoonName: string): BasePart?
	local tycoon = TycoonsFolder:FindFirstChild(tycoonName)
	local mainItems = tycoon and tycoon:FindFirstChild("MainItems")
	local ownerDoor = mainItems and mainItems:FindFirstChild("OwnerDoor")
	local door = ownerDoor and ownerDoor:FindFirstChild("Door")
	if door and door:IsA("BasePart") then
		return door
	end

	return nil
end

local function resolveTycoonPath(path: string): BasePart?
	local segments = string.split(path, ":")
	local tycoonName = segments[1]
	local current: Instance? = TycoonsFolder:FindFirstChild(tycoonName)
	for index = 2, #segments do
		if not current then
			return nil
		end
		current = current:FindFirstChild(segments[index])
	end

	if current and current:IsA("BasePart") then
		return current
	end

	return nil
end

local function resolveSignalTarget(target: any?): BasePart?
	if typeof(target) == "Instance" and target:IsA("BasePart") then
		return target
	elseif typeof(target) == "string" then
		return resolveTycoonPath(target)
	end

	return nil
end

local function markTycoonClaimed(target: any?)
	local door = resolveSignalTarget(target)
	if not door and typeof(target) == "string" then
		door = getDoorFromTycoonName(target)
	end

	if not door then
		return
	end

	local key = getDoorBeamKey(door)
	claimedDoorKeys[key] = true
	DisplaceBeam(key)
end

local function setupTycoonBeams()
	if not doorBeamsEnabled or not buttonDirectionsEnabled then
		return
	end

	for _, tycoon in TycoonsFolder:GetChildren() do
		local MainItems = tycoon:FindFirstChild("MainItems")
		if not MainItems then continue end

		local ownerDoor = MainItems:FindFirstChild("OwnerDoor")
		if not ownerDoor then continue end

		local Door = ownerDoor:FindFirstChild("Door")
		if not Door or not Door:IsA("BasePart") then continue end

		local key = getDoorBeamKey(Door)
		if claimedDoorKeys[key] then continue end

		local hrp = getHRP()
		if hrp then
			setBeam(hrp, Door, key)
		end
	end
end

RuntimeSettings.Observe('Allow Button Directions', function()
	buttonDirectionsEnabled = allowButtonDirections()
	if not buttonDirectionsEnabled then
		DisplaceAllBeams()
	else
		setupTycoonBeams()
	end
end)


Player.CharacterAdded:Connect(function(character)
	if not doorBeamsEnabled or not buttonDirectionsEnabled then
		return
	end

	local hrp = character:WaitForChild("HumanoidRootPart")
	for _, tycoon in TycoonsFolder:GetChildren() do
		local MainItems = tycoon:FindFirstChild("MainItems")
		if not MainItems then continue end
		local ownerDoor = MainItems:FindFirstChild("OwnerDoor")
		if not ownerDoor then continue end
		local Door = ownerDoor:FindFirstChild("Door")
		if not Door or not Door:IsA("BasePart") then continue end
		local key = getDoorBeamKey(Door)
		if claimedDoorKeys[key] then continue end
		setBeam(hrp, Door, key)
	end
end)



TutorialSignal.OnClientEvent:Connect(function(message: any, rawTarget: any?)
	local newMessage = decodeTutorialMessage(message)
	if not newMessage then
		return
	end

	local target = if typeof(rawTarget) == "string" then rawTarget else nil
	if newMessage == "TycoonClaimed" then
		markTycoonClaimed(target)
		return
	elseif newMessage == "TycoonAvailable" then
		doorBeamsEnabled = true
		local door = resolveSignalTarget(target)
		if not door and typeof(target) == "string" then
			door = getDoorFromTycoonName(target)
		end
		if door then
			local key = getDoorBeamKey(door)
			claimedDoorKeys[key] = nil
			local hrp = getHRP()
			if hrp then
				setBeam(hrp, door, key)
			end
		end
		return
	elseif newMessage == "Perfect!" then
		doorBeamsEnabled = false
		DisplaceAllBeams()
		return
	end
	if newMessage == "Congrats! Tutorial Completed." then
		DisplaceAllBeams()
		task.wait(3)
		script:Destroy()
		return
	end

	if newMessage == "Now purchase your first button!" then
		if not buttonDirectionsEnabled then
			return
		end
		local targetPart = resolveSignalTarget(target)
		if not targetPart then
			warn("[Onboarding] Target not found for button beam")
			return
		end
		DisplaceAllBeams()
		task.wait()
		local hrp = getHRP()
		if hrp then
			setBeam(hrp, targetPart, "tutorial_button")
		end

	elseif newMessage == "Claim your money" then
		if not buttonDirectionsEnabled then
			return
		end
		local targetPart = resolveSignalTarget(target)
		if not targetPart then
			warn("[Onboarding] Target not found for ATM beam")
			return
		end
		DisplaceAllBeams()
		task.wait()
		local hrp = getHRP()
		if hrp then
			setBeam(hrp, targetPart, "tutorial_atm")
		end
	end
end)

