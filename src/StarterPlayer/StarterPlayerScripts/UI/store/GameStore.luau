--!strict
--[[
	@class GameStore

	@desc
	Aggregator store that delegates to domain-specific sub-stores.
	Maintains backward compatibility: external consumers use GameStore.get()
	to access the singleton which exposes all sub-store methods.

	Sub-stores:
	- StatsStore          — leaderstats, stat sync
	- ProfileStore        — replica, XP, level, quests, daily
	- NotificationStore   — toast queue, weather notifications
	- NPCStore            — conversation state
	- KOTHStore           - KOTH announcements
	- NukeStore           - nuke cinematic
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)
local Janitor = require(ReplicatedStorage.Packages.janitor)
local PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)

local StatsStore = require(script.Parent.StatsStore)
local ProfileStore = require(script.Parent.ProfileStore)
local NotificationStore = require(script.Parent.NotificationStore)
local NPCStore = require(script.Parent.NPCStore)
local KOTHStore = require(script.Parent.KOTHStore)
local NukeStore = require(script.Parent.NukeStore)

--// Re-export types from sub-stores for backward compatibility
export type Stats = StatsStore.Stats
export type QuestProgress = ProfileStore.QuestProgress
export type ProfileState = ProfileStore.ProfileState
export type Notification = NotificationStore.Notification
export type KOTHAnnouncement = KOTHStore.KOTHAnnouncement
export type ConversationOption = NPCStore.ConversationOption
export type NPCConversation = NPCStore.NPCConversation
export type NukeCinematic = NukeStore.NukeCinematic

export type Snapshot = {
	stats: Stats,
	profile: ProfileState,
	notifications: { Notification },
	kothAnnouncement: KOTHAnnouncement?,
	npcConversation: NPCConversation?,
	nukeCinematic: NukeCinematic?,
}

--// Singleton

local Singleton: GameStore? = nil

--// Module

local GameStore = {}
GameStore.__index = GameStore

function GameStore.new(): GameStore
	local self = setmetatable({}, GameStore) :: GameStore

	self.StatsStore = StatsStore.new()
	self.ProfileStore = ProfileStore.new()
	self.NotificationStore = NotificationStore.new()
	self.NPCStore = NPCStore.new()
	self.KOTHStore = KOTHStore.new()
	self.NukeStore = NukeStore.new()

	self.Janitor = Janitor.new()
	self.Destroyed = false
	self.Started = false

	-- Wire sub-store changes to unified change signal
	self.Changed = Signal.new()

	return self
end

function GameStore:Start()
	if self.Started then
		return
	end

	self.Started = true

	-- Start sub-stores without packets first (for profile replica which uses its own)
	self.StatsStore:Start(nil)
	self.ProfileStore:Start(nil)
	self.NotificationStore:Start(nil)
	self.NPCStore:Start(nil)
	self.KOTHStore:Start(nil)
	self.NukeStore:Start(nil)

	-- Register cleanup
	self.Janitor:Add(self.StatsStore, "Destroy", "StatsStore")
	self.Janitor:Add(self.ProfileStore, "Destroy", "ProfileStore")
	self.Janitor:Add(self.NotificationStore, "Destroy", "NotificationStore")
	self.Janitor:Add(self.NPCStore, "Destroy", "NPCStore")
	self.Janitor:Add(self.KOTHStore, "Destroy", "KOTHStore")
	self.Janitor:Add(self.NukeStore, "Destroy", "NukeStore")

	-- Wire sub-store changes to unified signal
	self.Janitor:Add(self.StatsStore.Changed:Connect(function()
		self.Changed:Fire()
	end), "Disconnect", "StatsChanged")

	self.Janitor:Add(self.ProfileStore.Changed:Connect(function()
		self.Changed:Fire()
	end), "Disconnect", "ProfileChanged")

	self.Janitor:Add(self.NotificationStore.Changed:Connect(function()
		self.Changed:Fire()
	end), "Disconnect", "NotificationChanged")

	self.Janitor:Add(self.NPCStore.Changed:Connect(function()
		self.Changed:Fire()
	end), "Disconnect", "NPCChanged")

	self.Janitor:Add(self.KOTHStore.Changed:Connect(function()
		self.Changed:Fire()
	end), "Disconnect", "KOTHChanged")

	self.Janitor:Add(self.NukeStore.Changed:Connect(function()
		self.Changed:Fire()
	end), "Disconnect", "NukeChanged")

	-- Async start with packets once the shared namespace is ready
	self.Janitor:Add(task.spawn(function()
		-- PacketBootstrap owns the single readiness wait for the ByteNet namespace.
		local Packets = PacketBootstrap.Get()
		if not self.Started then
			return
		end

		-- Start sub-stores with packets (safe to call multiple times)
		self.StatsStore:Start(Packets)
		self.ProfileStore:Start(Packets)
		self.NotificationStore:Start(Packets)
		self.NPCStore:Start(Packets)
		self.KOTHStore:Start(Packets)
		self.NukeStore:Start(Packets)
	end), true, "AsyncPacketStart")

	-- Settings reminder notification
	self.Janitor:Add(task.delay(200, function()
		if not self.Started then
			return
		end

		self.NotificationStore:PushNotification("info", "You can turn off user announcements and button directions in Settings.", 6)
	end), true, "SettingsReminder")
end

function GameStore:TryGetPackets(): any
	return PacketBootstrap.TryGet()
end
--// Snapshot (combined from all sub-stores)

function GameStore:GetSnapshot(): Snapshot
	return {
		stats = self.StatsStore:GetSnapshot(),
		profile = self.ProfileStore:GetSnapshot(),
		notifications = self.NotificationStore:GetSnapshot(),
		kothAnnouncement = self.KOTHStore:GetSnapshot(),
		npcConversation = self.NPCStore:GetSnapshot(),
		nukeCinematic = self.NukeStore:GetNukeSnapshot(),
	}
end

function GameStore:Subscribe(Callback: () -> ()): () -> ()
	local Connection = self.Changed:Connect(Callback)
	return function()
		Connection:Disconnect()
	end
end

--// Delegated methods (backward compatibility)

function GameStore:SetStat(StatName: string, Value: number)
	self.StatsStore:SetStat(StatName, Value)
end

function GameStore:SetProfileState(State: any)
	self.ProfileStore:SetProfileState(State)
end

function GameStore:PushNotification(Kind: string, Message: string, Duration: number?)
	self.NotificationStore:PushNotification(Kind, Message, Duration)
end

function GameStore:PushTutorialNotification(Message: string, duration: number)
	self.NotificationStore:PushTutorialNotification(Message, duration)
end

function GameStore:ClearNotificationsByKind(Kind: string)
	self.NotificationStore:ClearNotificationsByKind(Kind)
end

function GameStore:DismissNotification(Id: number)
	self.NotificationStore:DismissNotification(Id)
end

function GameStore:DismissKOTHAnnouncement(Id: number)
	self.KOTHStore:DismissAnnouncement(Id)
end

function GameStore:ChooseNPCConversationOption(OptionId: string)
	local Conversation = self.NPCStore.Conversation
	if not Conversation then
		return
	end

	local Packets = self:TryGetPackets()
	if Packets then
		Packets.packets.NPCConversationChoice.send({
			action = "Choose",
			conversationId = Conversation.conversationId,
			optionId = OptionId,
		})
	end
end

function GameStore:EndNPCConversation()
	local Conversation = self.NPCStore.Conversation
	self.NPCStore.Conversation = nil
	self.NPCStore.Changed:Fire()

	if Conversation then
		local Packets = self:TryGetPackets()
		if Packets then
			Packets.packets.NPCConversationChoice.send({
				action = "End",
				conversationId = Conversation.conversationId,
			})
		end
	end
end

--// Lifecycle

function GameStore:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Started = false
	self.Janitor:Destroy()

	local Changed = self.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end

	if Singleton == self then
		Singleton = nil
	end
end

--// Singleton Accessor

function GameStore.get(): GameStore
	if not Singleton then
		Singleton = GameStore.new()
	end

	return Singleton
end

export type GameStore = typeof(setmetatable({} :: {
	StatsStore: any,
	ProfileStore: any,
	NotificationStore: any,
	NPCStore: any,
	KOTHStore: any,
	NukeStore: any,
	Janitor: any,
	Changed: any,
	Destroyed: boolean,
	Started: boolean,

	Start: (self: GameStore) -> (),
	TryGetPackets: (self: GameStore) -> any,
	GetSnapshot: (self: GameStore) -> Snapshot,
	Subscribe: (self: GameStore, Callback: () -> ()) -> () -> (),
	SetStat: (self: GameStore, StatName: string, Value: number) -> (),
	SetProfileState: (self: GameStore, State: any) -> (),
	PushNotification: (self: GameStore, Kind: string, Message: string, Duration: number?) -> (),
	PushTutorialNotification: (self: GameStore, Message: string) -> (),
	ClearNotificationsByKind: (self: GameStore, Kind: string) -> (),
	DismissNotification: (self: GameStore, Id: number) -> (),
	DismissKOTHAnnouncement: (self: GameStore, Id: number) -> (),
	ChooseNPCConversationOption: (self: GameStore, OptionId: string) -> (),
	EndNPCConversation: (self: GameStore) -> (),
	Destroy: (self: GameStore) -> (),
}, GameStore))

return GameStore
