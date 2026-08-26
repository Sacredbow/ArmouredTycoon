--!strict
--[[
	@class StatsStore

	@desc
	Manages player leaderstats (Cash, Emerald, Kills, Rebirths, Level, Experience).
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
	Level: number,
	Experience: number,
}

--// Constants

const DEFAULT_STATS: Stats = {
	Cash = 0,
	Emerald = 0,
	Kills = 0,
	Rebirths = 0,
	Level = 1,
	Experience = 0,
}

--// Internal Helpers

local function CopyStats(Stats: Stats): Stats
	return {
		Cash = Stats.Cash,
		Emerald = Stats.Emerald,
		Kills = Stats.Kills,
		Rebirths = Stats.Rebirths,
		Level = Stats.Level,
		Experience = Stats.Experience,
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
	self.Changed = Signal.new()
	self.Janitor = Janitor.new()
	self.LeaderstatsJanitor = Janitor.new()
	self.Destroyed = false

	return self
end

function StatsStore:Start(Packets: any)
	if self.Started then
		return
	end

	self.Started = true
	self:HydrateFromLeaderstats()
	self:BindLeaderstats()

	self.Janitor:Add(self.LeaderstatsJanitor, "Destroy", "Leaderstats")

	if Packets then
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

function StatsStore:BindLeaderstats()
	local Player = Players.LocalPlayer
	if not Player then
		return
	end

	local function ClearConnections()
		self.LeaderstatsJanitor:Cleanup()
	end

	local function BindValue(Value: Instance)
		if not DEFAULT_STATS[Value.Name] then
			return
		end
		if not Value:IsA("IntValue") and not Value:IsA("NumberValue") then
			return
		end

		self:SetStat(Value.Name, Value.Value)
		self.LeaderstatsJanitor:Add(Value.Changed:Connect(function(NewValue)
			if typeof(NewValue) == "number" then
				self:SetStat(Value.Name, NewValue)
			else
				self:SetStat(Value.Name, Value.Value)
			end
		end), "Disconnect", Value.Name)
	end

	local function BindFolder(Leaderstats: Instance)
		ClearConnections()
		for _, Child in ipairs(Leaderstats:GetChildren()) do
			BindValue(Child)
		end
		self.LeaderstatsJanitor:Add(Leaderstats.ChildAdded:Connect(BindValue), "Disconnect", "LeaderstatsChildAdded")
	end

	local Leaderstats = Player:FindFirstChild("leaderstats")
	if Leaderstats then
		BindFolder(Leaderstats)
	end

	self.Janitor:Add(Player.ChildAdded:Connect(function(Child)
		if Child.Name == "leaderstats" then
			BindFolder(Child)
		end
	end), "Disconnect", "PlayerChildAdded")
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

function StatsStore:SyncProfileLevel(Level: number, Experience: number)
	if self.Stats.Level ~= Level then
		self.Stats.Level = Level
	end
	if self.Stats.Experience ~= Experience then
		self.Stats.Experience = Experience
	end
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
	LeaderstatsJanitor: any,
	Destroyed: boolean,
	Started: boolean,

	Start: (self: StatsStore, Packets: any) -> (),
	HydrateFromLeaderstats: (self: StatsStore) -> (),
	BindLeaderstats: (self: StatsStore) -> (),
	GetSnapshot: (self: StatsStore) -> Stats,
	SetStat: (self: StatsStore, StatName: string, Value: number) -> (),
	SyncProfileLevel: (self: StatsStore, Level: number, Experience: number) -> (),
	Destroy: (self: StatsStore) -> (),
}, StatsStore))

return StatsStore

