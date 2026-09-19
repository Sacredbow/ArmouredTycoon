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
NPCStore.__index = NPCStore

function NPCStore.new(): NPCStore
	local self = setmetatable({}, NPCStore) :: NPCStore

	self.Conversation = nil
	self.Changed = Signal.new()
	self.Destroyed = false

	return self
end

function NPCStore:Start(Packets: any)
	if self.Started then
		return
	end

	-- Only mark as started when listeners actually register
	-- (see NotificationStore:Start for the GameStore Start(nil) flow).
	if not Packets then
		return
	end

	self.Started = true

	self.NPCConnection = Packets.packets.NPCConversation.listen(function(Payload)
		self:HandleConversation(Payload)
	end)
end

function NPCStore:HandleConversation(Payload: any)
	if type(Payload) ~= "table" then
		return
	end

	if Payload.action == "End" then
		self.Conversation = nil
		self.Changed:Fire()
		return
	end

	if Payload.action ~= "Open" then
		return
	end

	self.Conversation = {
		conversationId = tostring(Payload.conversationId or ""),
		npcName = tostring(Payload.npcName or "NPC"),
		npcLine = tostring(Payload.npcLine or ""),
		options = Payload.options or {},
		turnCount = tonumber(Payload.turnCount) or 0,
		maxTurns = tonumber(Payload.maxTurns) or 7,
	}
	self.Changed:Fire()
end

function NPCStore:GetSnapshot(): NPCConversation?
	if not self.Conversation then
		return nil
	end

	return {
		conversationId = self.Conversation.conversationId,
		npcName = self.Conversation.npcName,
		npcLine = self.Conversation.npcLine,
		options = self.Conversation.options,
		turnCount = self.Conversation.turnCount,
		maxTurns = self.Conversation.maxTurns,
	}
end

function NPCStore:IsActive(): boolean
	return self.Conversation ~= nil
end

function NPCStore:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Started = false

	if self.NPCConnection then
		self.NPCConnection:Disconnect()
		self.NPCConnection = nil
	end

	local Changed = self.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type NPCStore = typeof(setmetatable({} :: {
	Conversation: NPCConversation?,
	Changed: any,
	Destroyed: boolean,
	Started: boolean,
	NPCConnection: any?,

	Start: (self: NPCStore, Packets: any) -> (),
	HandleConversation: (self: NPCStore, Payload: any) -> (),
	GetSnapshot: (self: NPCStore) -> NPCConversation?,
	IsActive: (self: NPCStore) -> boolean,
	Destroy: (self: NPCStore) -> (),
}, NPCStore))

return NPCStore

