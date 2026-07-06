--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Network.Packets)
local Types = require(script.Parent.Parent.Core.Types)

type AIContext = Types.AIContext

local Speech = {}

function Speech.Say(context: AIContext, text: string)
	if text == "" then
		return
	end

	context.LastSpokenLine = text

	local adornee = context.NPC:FindFirstChild("Head")
	if not adornee or not adornee:IsA("BasePart") then
		adornee = context.PrimaryPart
	end
	if not adornee then
		return
	end

	Packets.packets.NPCSpeech.sendToAll({
		adornee = adornee,
		message = text,
	})

	if context.Config.DebugObservation then
		print(`[AI Speech] {context.Name}: {text}`)
	end
end

return Speech
