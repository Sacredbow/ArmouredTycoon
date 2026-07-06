--!strict

export type QuestCategory = "Daily" | "Weekly"

export type QuestDefinition = {
	id: string,
	category: QuestCategory,
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

export type QuestProgress = {
	Progress: number,
	Completed: boolean,
	Claimed: boolean,
}

local QuestOptions = {}

QuestOptions.DailyCooldown = 24 * 60 * 60
QuestOptions.WeeklyCooldown = 7 * 24 * 60 * 60

QuestOptions.Definitions = {
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
		id = "PaydayPatrol",
		category = "Daily",
		title = "Payday Patrol",
		subtitle = "Defeat 10 enemies for cash and XP.",
		metric = "Kill",
		goal = 10,
		reward = "$2,500",
		rewardCash = 2500,
		rewardEmerald = 0,
		rewardExperience = 120,
		accent = Color3.fromRGB(255, 190, 73),
	},
	{
		id = "SpringBoots",
		category = "Daily",
		title = "Spring Boots",
		subtitle = "Jump 10 times. Tiny cardio, big gains.",
		metric = "Jump",
		goal = 10,
		reward = "$750",
		rewardCash = 750,
		rewardEmerald = 0,
		rewardExperience = 60,
		accent = Color3.fromRGB(77, 171, 247),
	},
	{
		id = "CashCourier",
		category = "Daily",
		title = "Cash Courier",
		subtitle = "Earn $5,000 from any source.",
		metric = "CashEarned",
		goal = 5000,
		reward = "$1,250",
		rewardCash = 1250,
		rewardEmerald = 0,
		rewardExperience = 90,
		accent = Color3.fromRGB(255, 190, 73),
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
		id = "FirstBlood",
		category = "Daily",
		title = "First Blood",
		subtitle = "Get 1 clean takedown.",
		metric = "Kill",
		goal = 1,
		reward = "$500",
		rewardCash = 500,
		rewardEmerald = 0,
		rewardExperience = 45,
		accent = Color3.fromRGB(255, 93, 112),
	},
	{
		id = "FieldMedic",
		category = "Daily",
		title = "Field Promotion",
		subtitle = "Earn 200 XP.",
		metric = "ExperienceEarned",
		goal = 200,
		reward = "$1,000 + emerald",
		rewardCash = 1000,
		rewardEmerald = 1,
		rewardExperience = 80,
		accent = Color3.fromRGB(112, 217, 255),
	},
	{
		id = "RoyalErrand",
		category = "Daily",
		title = "Royal Errand",
		subtitle = "Claim any quest reward.",
		metric = "QuestClaim",
		goal = 1,
		reward = "+2 emeralds",
		rewardCash = 0,
		rewardEmerald = 2,
		rewardExperience = 80,
		accent = Color3.fromRGB(186, 132, 255),
	},
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
	{
		id = "Skybound",
		category = "Weekly",
		title = "Skybound",
		subtitle = "Jump 250 times.",
		metric = "Jump",
		goal = 250,
		reward = "$8,000",
		rewardCash = 8000,
		rewardEmerald = 8,
		rewardExperience = 450,
		accent = Color3.fromRGB(77, 171, 247),
	},
	{
		id = "DailyDevotee",
		category = "Weekly",
		title = "Daily Devotee",
		subtitle = "Claim 3 daily rewards.",
		metric = "DailyClaim",
		goal = 3,
		reward = "+12 emeralds",
		rewardCash = 12000,
		rewardEmerald = 12,
		rewardExperience = 600,
		accent = Color3.fromRGB(186, 132, 255),
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
}

QuestOptions.ById = {}
for _, definition in ipairs(QuestOptions.Definitions) do
	QuestOptions.ById[definition.id] = definition
end

function QuestOptions.createProgress(): QuestProgress
	return {
		Progress = 0,
		Completed = false,
		Claimed = false,
	}
end

function QuestOptions.createProgressMap(category: QuestCategory?): { [string]: QuestProgress }
	local progressByQuestId = {}
	for _, definition in ipairs(QuestOptions.Definitions) do
		if not category or definition.category == category then
			progressByQuestId[definition.id] = QuestOptions.createProgress()
		end
	end

	return progressByQuestId
end

return QuestOptions
