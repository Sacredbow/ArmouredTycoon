--!strict
--[[
	@class StatsStore

	@desc
	Manages player leaderstats (Cash, Emerald, Kills, Rebirths).
	Binds to Roblox leaderstats instance and fires on change.

	Owns:
	- leaderstats binding
	- StatSync packet listening
	- Stats type definition
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)
local Janitor = require(ReplicatedStorage.Packages.janitor)

--// Types

export type Stats = {
	Cash: number,
	Emerald: number,
	Kills: number,
	Rebirths: number,
}

--// Constants

const DEFAULT_STATS: Stats = {
	Cash = 0,
	Emerald = 0,
	Kills = 0,
	Rebirths = 0,
}

--// Internal Helpers

local function CopyStats(Stats: Stats): Stats
	return {
		Cash = Stats.Cash,
		Emerald = Stats.Emerald,
		Kills = Stats.Kills,
		Rebirths = Stats.Rebirths,
	}
end

local function ReadLeaderstat(Player: Player, StatName: string): number?
	local Leaderstats = Player:FindFirstChild("leaderstats")
	local Value = Leaderstats and Leaderstats:FindFirstChild(StatName)
	if Value and (Value:IsA("IntValue") or Value:IsA("NumberValue")) then
		return Value.Value
	end

	return nil
end

--// Module

local StatsStore = {}
StatsStore.__index = StatsStore

function StatsStore.new(): StatsStore
	local self = setmetatable({}, StatsStore) :: StatsStore

	self.Stats = CopyStats(DEFAULT_STATS)
	self.Changed = Signal.get("StatsStoreChanged")
	self.Janitor = Janitor.new()
	self.StatSyncConnected = false
	self.Destroyed = false

	return self
end

function StatsStore:Start(Packets: any)
	if not self.Started then
		self.Started = true
		self:HydrateFromLeaderstats()
		local hydrationTask = task.spawn(function()
			local Player = Players.LocalPlayer
			if not Player then
				return
			end

			local Leaderstats = Player:WaitForChild("leaderstats", 10)
			if self.Destroyed or not self.Started or not Leaderstats then
				return
			end

			self:HydrateFromLeaderstats()
			self.Changed:Fire()
		end)
		self.Janitor:Add(hydrationTask, true, "LeaderstatsHydration")
	end

	-- StatSync registration is independent of the started flag: GameStore
	-- calls Start(nil) first, then Start(Packets) once the network is ready.
	if Packets and not self.StatSyncConnected then
		self.StatSyncConnected = true
		self.Janitor:Add(Packets.packets.StatSync.listen(function(Data)
			self:SetStat(Data.stat, Data.value)
		end), nil, "StatSync")
	end
end

function StatsStore:HydrateFromLeaderstats()
	local Player = Players.LocalPlayer
	if not Player then
		return
	end

	for StatName in pairs(DEFAULT_STATS) do
		local Value = ReadLeaderstat(Player, StatName)
		if Value ~= nil then
			self.Stats[StatName] = Value
		end
	end
end

function StatsStore:GetSnapshot(): Stats
	return CopyStats(self.Stats)
end

function StatsStore:SetStat(StatName: string, Value: number)
	if self.Stats[StatName] == nil then
		return
	end

	local Rounded = math.floor(Value)
	if self.Stats[StatName] == Rounded then
		return
	end

	self.Stats[StatName] = Rounded
	self.Changed:Fire()
end


function StatsStore:Destroy()
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
end

export type StatsStore = typeof(setmetatable({} :: {
	Stats: Stats,
	Changed: any,
	Janitor: any,
	StatSyncConnected: boolean,
	Destroyed: boolean,
	Started: boolean,

	Start: (self: StatsStore, Packets: any) -> (),
	HydrateFromLeaderstats: (self: StatsStore) -> (),
	GetSnapshot: (self: StatsStore) -> Stats,
	SetStat: (self: StatsStore, StatName: string, Value: number) -> (),
	Destroy: (self: StatsStore) -> (),
}, StatsStore))

return StatsStore

