--!strict
--[[
	@class NotificationStore

	@desc
	Manages the toast notification queue.
	Handles dedup, tutorial persistence, and weather notifications.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer :: Player

local Signal = require(ReplicatedStorage.Packages.signal)
local Actions = require(ReplicatedStorage.Utilities.Actions)

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
NotificationStore.Notifications = {}
NotificationStore.Changed = Signal.get("NotificationStoreChanged")
NotificationStore.NextNotificationId = 0
NotificationStore.LastWeatherNotificationType = nil
NotificationStore.Destroyed = false
NotificationStore.Started = false
function NotificationStore.Start(Packets: any)
	if NotificationStore.Started then
		return
	end

	-- GameStore calls Start(nil) first, then Start(Packets) once the network
	-- is ready. Only mark as started when listeners actually register,
	-- otherwise the nil call would permanently skip registration.
	if not Packets then
		return
	end

	NotificationStore.Started = true
	
	
	type ControlsManager = {
		Disable: () -> (), 
		Enable: () -> (),

	}
	type PlayerModule = {
		GetControls: (self : PlayerModule) -> ControlsManager ,
		
	}
	


	-- Listen for Notification packets
	NotificationStore.NotificationConnection = Packets.packets.Notification.listen(function(Data)
		NotificationStore.PushNotification(Data.type, Data.message or "")
		if Data.RequiresFade then
			Actions.FadeScreen(0.5, 0.4, 2, "Classic", Color3.fromRGB(0, 0, 0))
			local PlayerScripts = Player:WaitForChild("PlayerScripts") :: typeof(Player.PlayerScripts)
			local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule")) :: ModuleScript & PlayerModule
			
		
			local Controls = PlayerModule:GetControls()
			Controls:Disable()
			
			task.wait(2)
			if NotificationStore.Destroyed or not NotificationStore.Started then
				return
			end
			Controls:Enable()
			
		end
	end)

	-- Listen for Weather packets (for weather-change notifications)
	NotificationStore.WeatherConnection = Packets.packets.Weather.listen(function(Data)
		NotificationStore.HandleWeatherNotification(Data)
	end)
end

--// Notification Queue

function NotificationStore.PushNotification(Type: string, Message: string, Duration: number?)
	NotificationStore.NextNotificationId += 1
	table.insert(NotificationStore.Notifications, 1, {
		id = NotificationStore.NextNotificationId,
		type = Type,
		message = Message,
		createdAt = os.clock(),
		duration = Duration or 2.35,
	})

	-- Trim excess notifications, preserving persistent tutorial ones
	while #NotificationStore.Notifications > MAX_VISIBLE_NOTIFICATIONS do
		local RemoveIndex: number? = nil
		for Index = #NotificationStore.Notifications, 1, -1 do
			if not NotificationStore.IsPersistentTutorial(NotificationStore.Notifications[Index]) then
				RemoveIndex = Index
				break
			end
		end

		table.remove(NotificationStore.Notifications, RemoveIndex or #NotificationStore.Notifications)
	end

	NotificationStore.Changed:Fire()
end

function NotificationStore.PushTutorialNotification(Message: string, duration: number?)
	NotificationStore.ClearNotificationsByKind("tutorial")
	NotificationStore.PushNotification("tutorial", Message, duration or 0)
end

function NotificationStore.ClearNotificationsByKind(Kind: string)
	local Changed = false
	for Index = #NotificationStore.Notifications, 1, -1 do
		if NotificationStore.Notifications[Index].type == Kind then
			table.remove(NotificationStore.Notifications, Index)
			Changed = true
		end
	end

	if Changed then
		NotificationStore.Changed:Fire()
	end
end

function NotificationStore.DismissNotification(Id: number)
	for Index, Notification in NotificationStore.Notifications do
		if Notification.id == Id then
			table.remove(NotificationStore.Notifications, Index)
			NotificationStore.Changed:Fire()
			return
		end
	end
end

function NotificationStore.GetSnapshot(): { Notification }
	local Copy = table.create(#NotificationStore.Notifications)
	for Index, Notification in NotificationStore.Notifications do
		Copy[Index] = Notification
	end

	return Copy
end

--// Weather Notifications (deduplicated)

function NotificationStore.HandleWeatherNotification(Data: { type: string })
	local WeatherType = Data.type
	if typeof(WeatherType) ~= "string" then
		return
	end

	if WeatherType == NotificationStore.LastWeatherNotificationType then
		return
	end

	NotificationStore.LastWeatherNotificationType = WeatherType
	if WeatherType == "Storm" then
		NotificationStore.PushNotification("warning", "Storm rolling in. Rain and thunder are active.", 5)
	elseif WeatherType == "Rain" then
		NotificationStore.PushNotification("info", "Rain is moving through the area.", 4)
	elseif WeatherType == "Fog" then
		NotificationStore.PushNotification("info", "Fog is settling across the map.", 4)
	end
end

--// Helpers

function NotificationStore.IsPersistentTutorial(Notification: Notification): boolean
	return Notification.type == "tutorial" and Notification.duration <= 0
end

--// Lifecycle

function NotificationStore.Destroy()
	if NotificationStore.Destroyed then
		return
	end

	NotificationStore.Destroyed = true
	NotificationStore.Started = false

	if NotificationStore.NotificationConnection then
		NotificationStore.NotificationConnection()
		NotificationStore.NotificationConnection = nil
	end

	if NotificationStore.WeatherConnection then
		NotificationStore.WeatherConnection()
		NotificationStore.WeatherConnection = nil
	end

	local Changed = NotificationStore.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type NotificationStore = typeof(NotificationStore)

return NotificationStore

