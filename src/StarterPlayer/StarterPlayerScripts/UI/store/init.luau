--!strict

local GameStore = require(script.GameStore)
local StatsStore = require(script.StatsStore)
local ProfileStore = require(script.ProfileStore)
local NotificationStore = require(script.NotificationStore)
local NPCStore = require(script.NPCStore)
local NukeStore = require(script.NukeStore)
local useGameStore = require(script.useGameStore)

return {
	GameStore = GameStore,
	StatsStore = StatsStore,
	ProfileStore = ProfileStore,
	NotificationStore = NotificationStore,
	NPCStore = NPCStore,
	NukeStore = NukeStore,
	useGameStore = useGameStore,
}

