--!strict
--[[
	@class HardQuests

	@desc
	Hard difficulty quests — require significant time investment and skill.
	Designed for end-game weekly progression with premium rewards.
]]

--// Types

export type QuestDefinition = {
	id: string,
	category: "Daily" | "Weekly",
	title: string,
	subtitle: string,
	metric: string,
	goal: number,
	reward: string,
	rewardCash: number,
	rewardEmerald: number,
	rewardExperience: number,
	accent: Color3,
}

--// Definitions

const HardQuestDefinitions: { QuestDefinition } = {
	-- Existing Hard Tier
	{
		id = "WarlordsLedger",
		category = "Weekly",
		title = "Warlord's Ledger",
		subtitle = "Defeat 100 enemies this week.",
		metric = "Kill",
		goal = 100,
		reward = "$20,000 + 25 emeralds",
		rewardCash = 20000,
		rewardEmerald = 25,
		rewardExperience = 1200,
		accent = Color3.fromRGB(255, 93, 112),
	},
	{
		id = "VaultBreaker",
		category = "Weekly",
		title = "Vault Breaker",
		subtitle = "Earn $100,000.",
		metric = "CashEarned",
		goal = 100000,
		reward = "$30,000",
		rewardCash = 30000,
		rewardEmerald = 10,
		rewardExperience = 1000,
		accent = Color3.fromRGB(255, 190, 73),
	},
	{
		id = "PhoenixContract",
		category = "Weekly",
		title = "Phoenix Contract",
		subtitle = "Rebirth once.",
		metric = "Rebirth",
		goal = 1,
		reward = "huge XP",
		rewardCash = 15000,
		rewardEmerald = 15,
		rewardExperience = 1500,
		accent = Color3.fromRGB(255, 140, 73),
	},
	-- New Hard Tier
	{
		id = "ReignOfTerror",
		category = "Weekly",
		title = "Reign of Terror",
		subtitle = "Achieve a 10 killstreak.",
		metric = "Killstreak",
		goal = 10,
		reward = "$25,000 + 30 emeralds",
		rewardCash = 25000,
		rewardEmerald = 30,
		rewardExperience = 1600,
		accent = Color3.fromRGB(255, 60, 60),
	},
	{
		id = "BoxCollector",
		category = "Weekly",
		title = "Box Collector",
		subtitle = "Open 20 loot boxes.",
		metric = "BoxOpened",
		goal = 20,
		reward = "$22,000 + 15 emeralds",
		rewardCash = 22000,
		rewardEmerald = 15,
		rewardExperience = 1100,
		accent = Color3.fromRGB(186, 132, 255),
	},
	{
		id = "MaxCombo",
		category = "Weekly",
		title = "Max Combo",
		subtitle = "Land 5 consecutive headshots.",
		metric = "HeadshotCombo",
		goal = 5,
		reward = "$28,000 + 20 emeralds",
		rewardCash = 28000,
		rewardEmerald = 20,
		rewardExperience = 1300,
		accent = Color3.fromRGB(255, 93, 112),
	},
	{
		id = "TycoonMogul",
		category = "Weekly",
		title = "Tycoon Mogul",
		subtitle = "Purchase 25 tycoon upgrades.",
		metric = "TycoonPurchase",
		goal = 25,
		reward = "$35,000 + 25 emeralds",
		rewardCash = 35000,
		rewardEmerald = 25,
		rewardExperience = 1800,
		accent = Color3.fromRGB(255, 190, 73),
	},
}

return HardQuestDefinitions

