--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
local Types = require(script.Parent.Parent.Core.Types)

type AIContext = Types.AIContext

local Speech = {}
local SPEECH_RADIUS = 180

function Speech.Say(context: AIContext, text: string)
	if text == "" then
		return
	end

	context.LastSpokenLine = text

	local adornee = context.NPC:FindFirstChild("Head")
	if not adornee or not adornee:IsA("BasePart") then
		adornee = context.PrimaryPart
	end
	if not adornee or not adornee:IsA("BasePart") then
		return
	end

	local listeners = {}
	local origin = adornee.Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - origin).Magnitude <= SPEECH_RADIUS then
			table.insert(listeners, player)
		end
	end
	if #listeners > 0 then
		Packets.packets.NPCSpeech.sendToList({
			adornee = adornee,
			message = text,
		}, listeners)
	end

	if context.Config.DebugObservation then
		print(`[AI Speech] {context.Name}: {text}`)
	end
end

return Speech
