--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)
local RuntimeSettings = require(ReplicatedStorage.Shared.Platform.Settings.RuntimeSettings)
local SettingsConfig = require(ReplicatedStorage.Shared.Platform.Settings.SettingsConfig)

export type KOTHAnnouncement = {
	id: number,
	playerName: string,
	teamColor: Color3,
	minutes: number?,
	createdAt: number,
	duration: number,
}

local KOTHStore = {}
KOTHStore.Announcement = nil
KOTHStore.Changed = Signal.get("KOTHStoreChanged")
KOTHStore.NextAnnouncementId = 0
KOTHStore.Started = false
KOTHStore.Destroyed = false

function KOTHStore.Start(Packets: any)
	if KOTHStore.Started or not Packets then
		return
	end

	KOTHStore.PacketDisconnect = Packets.packets.KOTHAnnouncement.listen(function(data)
		KOTHStore.PushAnnouncement(data.playerName, data.teamColor, data.minutes)
	end)
	KOTHStore.SettingsConnection = RuntimeSettings.Observe("User Announcements", function(value)
		if value ~= true and KOTHStore.Announcement then
			KOTHStore.Announcement = nil
			KOTHStore.Changed:Fire()
		end
	end)
	KOTHStore.Started = true
end

function KOTHStore.PushAnnouncement(playerName: string, teamColor: Color3, minutes: number?)
	if
		RuntimeSettings.GetBoolean("User Announcements", SettingsConfig.default_settings["User Announcements"] == true)
		~= true
	then
		return
	end

	KOTHStore.NextAnnouncementId += 1
	KOTHStore.Announcement = {
		id = KOTHStore.NextAnnouncementId,
		playerName = playerName,
		teamColor = teamColor,
		minutes = minutes,
		createdAt = os.clock(),
		duration = 4.5,
	}
	KOTHStore.Changed:Fire()
end

function KOTHStore.DismissAnnouncement(id: number)
	if KOTHStore.Announcement and KOTHStore.Announcement.id == id then
		KOTHStore.Announcement = nil
		KOTHStore.Changed:Fire()
	end
end

function KOTHStore.GetSnapshot(): KOTHAnnouncement?
	return if KOTHStore.Announcement then table.clone(KOTHStore.Announcement) else nil
end

function KOTHStore.Destroy()
	if KOTHStore.Destroyed then
		return
	end

	KOTHStore.Destroyed = true
	KOTHStore.Started = false
	if KOTHStore.PacketDisconnect then
		KOTHStore.PacketDisconnect()
		KOTHStore.PacketDisconnect = nil
	end
	if KOTHStore.SettingsConnection then
		KOTHStore.SettingsConnection:Disconnect()
		KOTHStore.SettingsConnection = nil
	end
	KOTHStore.Changed:Destroy()
end

export type KOTHStore = typeof(KOTHStore)

return KOTHStore
