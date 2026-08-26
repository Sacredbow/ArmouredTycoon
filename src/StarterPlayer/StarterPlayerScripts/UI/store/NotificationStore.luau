--!strict
--[[
	@class NotificationStore

	@desc
	Manages the toast notification queue.
	Handles dedup, tutorial persistence, and weather notifications.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)

--// Types

export type Notification = {
	id: number,
	type: string,
	message: string,
	createdAt: number,
	duration: number,
}

--// Constants

const MAX_VISIBLE_NOTIFICATIONS = 4

--// Module

local NotificationStore = {}
NotificationStore.__index = NotificationStore

function NotificationStore.new(): NotificationStore
	local self = setmetatable({}, NotificationStore) :: NotificationStore

	self.Notifications = {}
	self.Changed = Signal.new()
	self.NextNotificationId = 0
	self.LastWeatherNotificationType = nil
	self.Destroyed = false

	return self
end

function NotificationStore:Start(Packets: any)
	if self.Started then
		return
	end

	self.Started = true

	if not Packets then
		return
	end

	-- Listen for Notification packets
	self.NotificationConnection = Packets.packets.Notification.listen(function(Data)
		self:PushNotification(Data.type, Data.message or "")
	end)

	-- Listen for Weather packets (for weather-change notifications)
	self.WeatherConnection = Packets.packets.Weather.listen(function(Data)
		self:HandleWeatherNotification(Data)
	end)
end

--// Notification Queue

function NotificationStore:PushNotification(Type: string, Message: string, Duration: number?)
	self.NextNotificationId += 1
	table.insert(self.Notifications, 1, {
		id = self.NextNotificationId,
		type = Type,
		message = Message,
		createdAt = os.clock(),
		duration = Duration or 2.35,
	})

	-- Trim excess notifications, preserving persistent tutorial ones
	while #self.Notifications > MAX_VISIBLE_NOTIFICATIONS do
		local RemoveIndex: number? = nil
		for Index = #self.Notifications, 1, -1 do
			if not self:IsPersistentTutorial(self.Notifications[Index]) then
				RemoveIndex = Index
				break
			end
		end

		table.remove(self.Notifications, RemoveIndex or #self.Notifications)
	end

	self.Changed:Fire()
end

function NotificationStore:PushTutorialNotification(Message: string)
	self:ClearNotificationsByKind("tutorial")
	self:PushNotification("tutorial", Message, 0)
end

function NotificationStore:ClearNotificationsByKind(Kind: string)
	local Changed = false
	for Index = #self.Notifications, 1, -1 do
		if self.Notifications[Index].type == Kind then
			table.remove(self.Notifications, Index)
			Changed = true
		end
	end

	if Changed then
		self.Changed:Fire()
	end
end

function NotificationStore:DismissNotification(Id: number)
	for Index, Notification in ipairs(self.Notifications) do
		if Notification.id == Id then
			table.remove(self.Notifications, Index)
			self.Changed:Fire()
			return
		end
	end
end

function NotificationStore:GetSnapshot(): { Notification }
	local Copy = table.create(#self.Notifications)
	for Index, Notification in ipairs(self.Notifications) do
		Copy[Index] = Notification
	end

	return Copy
end

--// Weather Notifications (deduplicated)

function NotificationStore:HandleWeatherNotification(Data: { type: string })
	local WeatherType = Data.type
	if typeof(WeatherType) ~= "string" then
		return
	end

	if WeatherType == self.LastWeatherNotificationType then
		return
	end

	self.LastWeatherNotificationType = WeatherType
	if WeatherType == "Storm" then
		self:PushNotification("warning", "Storm rolling in. Rain and thunder are active.", 5)
	elseif WeatherType == "Rain" then
		self:PushNotification("info", "Rain is moving through the area.", 4)
	elseif WeatherType == "Fog" then
		self:PushNotification("info", "Fog is settling across the map.", 4)
	end
end

--// Helpers

function NotificationStore:IsPersistentTutorial(Notification: Notification): boolean
	return Notification.type == "tutorial" and Notification.duration <= 0
end

--// Lifecycle

function NotificationStore:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Started = false

	if self.NotificationConnection then
		self.NotificationConnection:Disconnect()
		self.NotificationConnection = nil
	end

	if self.WeatherConnection then
		self.WeatherConnection:Disconnect()
		self.WeatherConnection = nil
	end

	local Changed = self.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type NotificationStore = typeof(setmetatable({} :: {
	Notifications: { Notification },
	Changed: any,
	Destroyed: boolean,
	Started: boolean,
	NextNotificationId: number,
	LastWeatherNotificationType: string?,
	NotificationConnection: any?,
	WeatherConnection: any?,

	Start: (self: NotificationStore, Packets: any) -> (),
	PushNotification: (self: NotificationStore, Type: string, Message: string, Duration: number?) -> (),
	PushTutorialNotification: (self: NotificationStore, Message: string) -> (),
	ClearNotificationsByKind: (self: NotificationStore, Kind: string) -> (),
	DismissNotification: (self: NotificationStore, Id: number) -> (),
	GetSnapshot: (self: NotificationStore) -> { Notification },
	HandleWeatherNotification: (self: NotificationStore, Data: { type: string }) -> (),
	IsPersistentTutorial: (self: NotificationStore, Notification: Notification) -> boolean,
	Destroy: (self: NotificationStore) -> (),
}, NotificationStore))

return NotificationStore

