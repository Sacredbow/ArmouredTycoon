--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Core.Types)

type AIContext = Types.AIContext

local REMOTES_FOLDER_NAME = "Remotes"
local BUBBLE_REMOTE_NAME = "NPCBubbleSpeech"

local Speech = {}

local function getRemoteEvent(): RemoteEvent
	local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end

	local remote = remotesFolder:FindFirstChild(BUBBLE_REMOTE_NAME)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = BUBBLE_REMOTE_NAME
	newRemote.Parent = remotesFolder
	return newRemote
end

function Speech.Say(context: AIContext, text: string)
	if text == "" then
		return
	end

	context.LastSpokenLine = text

	local adornee = context.NPC:FindFirstChild("Head")
	if not adornee or not adornee:IsA("BasePart") then
		adornee = context.PrimaryPart
	end

	getRemoteEvent():FireAllClients(adornee, text)

	if context.Config.DebugObservation then
		print(`[AI Speech] {context.Name}: {text}`)
	end
end

return Speech
