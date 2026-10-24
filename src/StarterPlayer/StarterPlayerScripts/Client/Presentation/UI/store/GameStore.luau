--!strict
-- Aggregates the client stores behind one module-level presentation API.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)
local Janitor = require(ReplicatedStorage.Packages.janitor)
local PacketBootstrap = require(ReplicatedStorage.Shared.Platform.Network.PacketBootstrap)

local StatsStore = require(script.Parent.StatsStore)
local ProfileStore = require(script.Parent.ProfileStore)
local NotificationStore = require(script.Parent.NotificationStore)
local NPCStore = require(script.Parent.NPCStore)
local KOTHStore = require(script.Parent.KOTHStore)
local NukeStore = require(script.Parent.NukeStore)

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

local GameStore = {
	StatsStore = StatsStore,
	ProfileStore = ProfileStore,
	NotificationStore = NotificationStore,
	NPCStore = NPCStore,
	KOTHStore = KOTHStore,
	NukeStore = NukeStore,
	Janitor = Janitor.new(),
	Changed = Signal.get("GameStoreChanged"),
	Destroyed = false,
	Started = false,
}

function GameStore.PublishChange()
	GameStore.Changed:Fire()
end

function GameStore.Start()
	if GameStore.Started then
		return
	end
	GameStore.Started = true

	StatsStore.Start(nil)
	ProfileStore.Start(nil)
	NotificationStore.Start(nil)
	NPCStore.Start(nil)
	KOTHStore.Start(nil)
	NukeStore.Start(nil)

	GameStore.Janitor:Add(StatsStore.Changed:Connect(GameStore.PublishChange), "Disconnect", "StatsChanged")
	GameStore.Janitor:Add(ProfileStore.Changed:Connect(GameStore.PublishChange), "Disconnect", "ProfileChanged")
	GameStore.Janitor:Add(
		NotificationStore.Changed:Connect(GameStore.PublishChange),
		"Disconnect",
		"NotificationChanged"
	)
	GameStore.Janitor:Add(NPCStore.Changed:Connect(GameStore.PublishChange), "Disconnect", "NPCChanged")
	GameStore.Janitor:Add(KOTHStore.Changed:Connect(GameStore.PublishChange), "Disconnect", "KOTHChanged")
	GameStore.Janitor:Add(NukeStore.Changed:Connect(GameStore.PublishChange), "Disconnect", "NukeChanged")

	GameStore.Janitor:Add(
		task.spawn(function()
			local Packets = PacketBootstrap.Get()
			if not GameStore.Started then
				return
			end
			StatsStore.Start(Packets)
			ProfileStore.Start(Packets)
			NotificationStore.Start(Packets)
			NPCStore.Start(Packets)
			KOTHStore.Start(Packets)
			NukeStore.Start(Packets)
		end),
		true,
		"AsyncPacketStart"
	)

	GameStore.Janitor:Add(
		task.delay(200, function()
			if GameStore.Started then
				NotificationStore.PushNotification(
					"info",
					"You can turn off user announcements and button directions in Settings.",
					6
				)
			end
		end),
		true,
		"SettingsReminder"
	)
end

function GameStore.TryGetPackets(): any
	return PacketBootstrap.TryGet()
end

function GameStore.GetSnapshot(): Snapshot
	return {
		stats = StatsStore.GetSnapshot(),
		profile = ProfileStore.GetSnapshot(),
		notifications = NotificationStore.GetSnapshot(),
		kothAnnouncement = KOTHStore.GetSnapshot(),
		npcConversation = NPCStore.GetSnapshot(),
		nukeCinematic = NukeStore.GetNukeSnapshot(),
	}
end

function GameStore.Subscribe(Callback: () -> ()): () -> ()
	local Connection = GameStore.Changed:Connect(Callback)
	return function()
		Connection:Disconnect()
	end
end

function GameStore.SetStat(StatName: string, Value: number)
	StatsStore.SetStat(StatName, Value)
end
function GameStore.SetProfileState(State: any)
	ProfileStore.SetProfileState(State)
end
function GameStore.PushNotification(Kind: string, Message: string, Duration: number?)
	NotificationStore.PushNotification(Kind, Message, Duration)
end
function GameStore.PushTutorialNotification(Message: string, Duration: number?)
	NotificationStore.PushTutorialNotification(Message, Duration)
end
function GameStore.ClearNotificationsByKind(Kind: string)
	NotificationStore.ClearNotificationsByKind(Kind)
end
function GameStore.DismissNotification(Id: number)
	NotificationStore.DismissNotification(Id)
end
function GameStore.DismissKOTHAnnouncement(Id: number)
	KOTHStore.DismissAnnouncement(Id)
end

function GameStore.ChooseNPCConversationOption(OptionId: string)
	local Conversation = NPCStore.Conversation
	if not Conversation then
		return
	end
	local Packets = GameStore.TryGetPackets()
	if Packets then
		Packets.packets.NPCConversationChoice.send({
			action = "Choose",
			conversationId = Conversation.conversationId,
			optionId = OptionId,
		})
	end
end

function GameStore.EndNPCConversation()
	local Conversation = NPCStore.Conversation
	NPCStore.Conversation = nil
	NPCStore.Changed:Fire()
	if Conversation then
		local Packets = GameStore.TryGetPackets()
		if Packets then
			Packets.packets.NPCConversationChoice.send({
				action = "End",
				conversationId = Conversation.conversationId,
			})
		end
	end
end

function GameStore.Destroy()
	if GameStore.Destroyed then
		return
	end
	GameStore.Destroyed = true
	GameStore.Started = false
	GameStore.Janitor:Destroy()
	local Changed = GameStore.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

function GameStore.get(): typeof(GameStore)
	return GameStore
end
export type GameStore = typeof(GameStore)

return GameStore
