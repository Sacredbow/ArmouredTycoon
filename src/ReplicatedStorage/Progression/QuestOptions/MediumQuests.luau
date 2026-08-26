--!strict
--[[
	@class MediumQuests

	@desc
	Medium difficulty quests — require moderate effort and engagement.
	Balanced for active daily and weekly progression.
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

const MediumQuestDefinitions: { QuestDefinition } = {
	-- Existing Medium Tier
	{
		id = "QueensWish",
		category = "Daily",
		title = "A Queen's Wish",
		subtitle = "Defeat 25 enemies for emeralds.",
		metric = "Kill",
		goal = 25,
		reward = "+8 emeralds",
		rewardCash = 0,
		rewardEmerald = 8,
		rewardExperience = 250,
		accent = Color3.fromRGB(62, 236, 119),
	},
	{
		id = "GemWhisper",
		category = "Daily",
		title = "Gem Whisper",
		subtitle = "Earn 5 emeralds.",
		metric = "EmeraldEarned",
		goal = 5,
		reward = "+3 emeralds",
		rewardCash = 0,
		rewardEmerald = 3,
		rewardExperience = 100,
		accent = Color3.fromRGB(62, 236, 119),
	},
	{
		id = "QuestKnight",
		category = "Weekly",
		title = "Quest Knight",
		subtitle = "Claim 8 quest rewards.",
		metric = "QuestClaim",
		goal = 8,
		reward = "$18,000 + 18 emeralds",
		rewardCash = 18000,
		rewardEmerald = 18,
		rewardExperience = 850,
		accent = Color3.fromRGB(112, 217, 255),
	},
	{
		id = "EmeraldCrown",
		category = "Weekly",
		title = "Emerald Crown",
		subtitle = "Earn 50 emeralds.",
		metric = "EmeraldEarned",
		goal = 50,
		reward = "+20 emeralds",
		rewardCash = 10000,
		rewardEmerald = 20,
		rewardExperience = 900,
		accent = Color3.fromRGB(62, 236, 119),
	},
	-- New Medium Tier
	{
		id = "Sharpshooter",
		category = "Daily",
		title = "Sharpshooter",
		subtitle = "Land 30 shots on enemies.",
		metric = "Hit",
		goal = 30,
		reward = "$4,000",
		rewardCash = 4000,
		rewardEmerald = 2,
		rewardExperience = 180,
		accent = Color3.fromRGB(255, 214, 73),
	},
	{
		id = "Undefeated",
		category = "Daily",
		title = "Undefeated",
		subtitle = "Win 3 duels against players.",
		metric = "DuelWin",
		goal = 3,
		reward = "$6,000 + emerald",
		rewardCash = 6000,
		rewardEmerald = 3,
		rewardExperience = 220,
		accent = Color3.fromRGB(255, 93, 112),
	},
	{
		id = "SupplyRun",
		category = "Weekly",
		title = "Supply Run",
		subtitle = "Open 5 loot boxes.",
		metric = "BoxOpened",
		goal = 5,
		reward = "$12,000 + 10 emeralds",
		rewardCash = 12000,
		rewardEmerald = 10,
		rewardExperience = 550,
		accent = Color3.fromRGB(186, 132, 255),
	},
	{
		id = "HeadHunter",
		category = "Weekly",
		title = "Head Hunter",
		subtitle = "Land 40 headshots.",
		metric = "Headshot",
		goal = 40,
		reward = "$15,000 + 12 emeralds",
		rewardCash = 15000,
		rewardEmerald = 12,
		rewardExperience = 700,
		accent = Color3.fromRGB(255, 93, 112),
	},
}

return MediumQuestDefinitions

