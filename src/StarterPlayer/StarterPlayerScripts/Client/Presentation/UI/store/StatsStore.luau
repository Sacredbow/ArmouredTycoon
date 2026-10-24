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
StatsStore.Stats = CopyStats(DEFAULT_STATS)
StatsStore.Changed = Signal.get("StatsStoreChanged")
StatsStore.Janitor = Janitor.new()
StatsStore.StatSyncConnected = false
StatsStore.Destroyed = false
StatsStore.Started = false
function StatsStore.Start(Packets: any)
	if not StatsStore.Started then
		StatsStore.Started = true
		StatsStore.HydrateFromLeaderstats()
		local hydrationTask = task.spawn(function()
			local Player = Players.LocalPlayer
			if not Player then
				return
			end

			local Leaderstats = Player:WaitForChild("leaderstats", 10)
			if StatsStore.Destroyed or not StatsStore.Started or not Leaderstats then
				return
			end

			StatsStore.HydrateFromLeaderstats()
			StatsStore.Changed:Fire()
		end)
		StatsStore.Janitor:Add(hydrationTask, true, "LeaderstatsHydration")
	end

	-- StatSync registration is independent of the started flag: GameStore
	-- calls Start(nil) first, then Start(Packets) once the network is ready.
	if Packets and not StatsStore.StatSyncConnected then
		StatsStore.StatSyncConnected = true
		StatsStore.Janitor:Add(Packets.packets.StatSync.listen(function(Data)
			StatsStore.SetStat(Data.stat, Data.value)
		end), nil, "StatSync")
	end
end

function StatsStore.HydrateFromLeaderstats()
	local Player = Players.LocalPlayer
	if not Player then
		return
	end

	for StatName in DEFAULT_STATS do
		local Value = ReadLeaderstat(Player, StatName)
		if Value ~= nil then
			StatsStore.Stats[StatName] = Value
		end
	end
end

function StatsStore.GetSnapshot(): Stats
	return CopyStats(StatsStore.Stats)
end

function StatsStore.SetStat(StatName: string, Value: number)
	if StatsStore.Stats[StatName] == nil then
		return
	end

	local Rounded = math.floor(Value)
	if StatsStore.Stats[StatName] == Rounded then
		return
	end

	StatsStore.Stats[StatName] = Rounded
	StatsStore.Changed:Fire()
end


function StatsStore.Destroy()
	if StatsStore.Destroyed then
		return
	end

	StatsStore.Destroyed = true
	StatsStore.Started = false
	StatsStore.Janitor:Destroy()

	local Changed = StatsStore.Changed :: any
	if Changed.Destroy then
		Changed:Destroy()
	end
end

export type StatsStore = typeof(StatsStore)

return StatsStore

