--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)
local RuntimeSettings = require(ReplicatedStorage.Modules.SettingsManager.RuntimeSettings)
local SettingsConfig = require(ReplicatedStorage.Modules.SettingsManager.SettingsConfig)

export type KOTHAnnouncement = {
	id: number,
	playerName: string,
	teamColor: Color3,
	minutes: number?,
	createdAt: number,
	duration: number,
}

local KOTHStore = {}
KOTHStore.__index = KOTHStore

function KOTHStore.new(): KOTHStore
	local self = setmetatable({}, KOTHStore) :: KOTHStore
	self.Announcement = nil
	self.Changed = Signal.new()
	self.NextAnnouncementId = 0
	self.Started = false
	self.Destroyed = false
	return self
end

function KOTHStore:Start(Packets: any)
	if self.Started or not Packets then
		return
	end

	self.PacketDisconnect = Packets.packets.KOTHAnnouncement.listen(function(data)
		self:PushAnnouncement(data.playerName, data.teamColor, data.minutes)
	end)
	self.SettingsConnection = RuntimeSettings.Observe("User Announcements", function(value)
		if value ~= true and self.Announcement then
			self.Announcement = nil
			self.Changed:Fire()
		end
	end)
	self.Started = true
end

function KOTHStore:PushAnnouncement(playerName: string, teamColor: Color3, minutes: number?)
	if RuntimeSettings.GetBoolean("User Announcements", SettingsConfig.default_settings["User Announcements"] == true) ~= true then
		return
	end

	self.NextAnnouncementId += 1
	self.Announcement = {
		id = self.NextAnnouncementId,
		playerName = playerName,
		teamColor = teamColor,
		minutes = minutes,
		createdAt = os.clock(),
		duration = 4.5,
	}
	self.Changed:Fire()
end

function KOTHStore:DismissAnnouncement(id: number)
	if self.Announcement and self.Announcement.id == id then
		self.Announcement = nil
		self.Changed:Fire()
	end
end

function KOTHStore:GetSnapshot(): KOTHAnnouncement?
	return self.Announcement
end

function KOTHStore:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Started = false
	if self.PacketDisconnect then
		self.PacketDisconnect()
		self.PacketDisconnect = nil
	end
	if self.SettingsConnection then
		self.SettingsConnection:Disconnect()
		self.SettingsConnection = nil
	end
	self.Changed:Destroy()
end

export type KOTHStore = typeof(setmetatable({} :: {
	Announcement: KOTHAnnouncement?,
	Changed: any,
	NextAnnouncementId: number,
	Started: boolean,
	Destroyed: boolean,
	PacketDisconnect: (() -> ())?,
	SettingsConnection: RuntimeSettings.SettingConnection?,
}, KOTHStore))

return KOTHStore
