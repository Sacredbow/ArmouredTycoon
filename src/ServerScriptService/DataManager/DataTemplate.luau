local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestOptions = require(ReplicatedStorage.Shared.Game.Progression.QuestOptions)

return {
	Cash = 125,
	Emerald = 15,
	Kills = 0,
	Rebirths = 0,
	Onboarding = false,
	Level = 1,
	Experience = 0,
	LastDailyReward = 0,
	QuestCycles = {
		DailyStart = 0,
		WeeklyStart = 0,
	},
	Quests = QuestOptions.createProgressMap(),
	TycoonConstruction = {
		PurchasedButtons = {},
		ConfigVersion = 1,
	},
	BuildService = {
		PlacedBuilds = {},
	},
	ProcessedReceipts = {}, -- PurchaseId -> Unix timestamp
	RedeemedCodes = {
		-- ["CODE"] = redeemedAtUnixTimestamp
	},
}
