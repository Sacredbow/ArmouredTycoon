--!strict
--[[
	@class NPCStore

	@desc
	Manages NPC conversation state.
	Handles conversation flow, options, and turn tracking.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)

--// Types

export type ConversationOption = {
	id: string,
	text: string,
	tone: string,
}

export type NPCConversation = {
	conversationId: string,
	npcName: string,
	npcLine: string,
	options: { ConversationOption },
	turnCount: number,
	maxTurns: number,
}

--// Module

local NPCStore = {}
NPCStore.Conversation = nil
NPCStore.Changed = Signal.get("NPCStoreChanged")
NPCStore.Destroyed = false
NPCStore.Started = false
function NPCStore.Start(Packets: any)
	if NPCStore.Started then
		return
	end

	-- Only mark as started when listeners actually register
	-- (see NotificationStore:Start for the GameStore Start(nil) flow).
	if not Packets then
		return
	end

	NPCStore.Started = true

	NPCStore.NPCConnection = Packets.packets.NPCConversation.listen(function(Payload)
		NPCStore.HandleConversation(Payload)
	end)
end

function NPCStore.HandleConversation(Payload: any)
	if type(Payload) ~= "table" then
		return
	end

	if Payload.action == "End" then
		NPCStore.Conversation = nil
		NPCStore.Changed:Fire()
		return
	end

	if Payload.action ~= "Open" then
		return
	end

	NPCStore.Conversation = {
		conversationId = tostring(Payload.conversationId or ""),
		npcName = tostring(Payload.npcName or "NPC"),
		npcLine = tostring(Payload.npcLine or ""),
		options = Payload.options or {},
		turnCount = tonumber(Payload.turnCount) or 0,
		maxTurns = tonumber(Payload.maxTurns) or 7,
	}
	NPCStore.Changed:Fire()
end

function NPCStore.GetSnapshot(): NPCConversation?
	if not NPCStore.Conversation then
		return nil
	end

	return {
		conversationId = NPCStore.Conversation.conversationId,
		npcName = NPCStore.Conversation.npcName,
		npcLine = NPCStore.Conversation.npcLine,
		options = NPCStore.Conversation.options,
		turnCount = NPCStore.Conversation.turnCount,
		maxTurns = NPCStore.Conversation.maxTurns,
	}
end

function NPCStore.IsActive(): boolean
	return NPCStore.Conversation ~= nil
end

function NPCStore.Destroy()
	if NPCStore.Destroyed then
		return
	end

	NPCStore.Destroyed = true
	NPCStore.Started = false

	if NPCStore.NPCConnection then
		NPCStore.NPCConnection()
		NPCStore.NPCConnection = nil
	end

	local Changed = NPCStore.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type NPCStore = typeof(NPCStore)

return NPCStore
