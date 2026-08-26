--!strict
--[[
	@class QuestProgression

	@desc
	Manages quest lifecycle — ensures profile data, advances progress
	by metric, and validates claims. Works with QuestOptions definitions.

	Moved from Quests/ subfolder to Progression/ for cleaner require paths.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const QuestOptions = require(ReplicatedStorage.Progression.QuestOptions)

--// Module

local QuestProgression = {}

--// Internal Utilities

local function GetData(Profile: any): any
	return Profile.Data
end

--// Public API

function QuestProgression.ensure(Profile: any, Now: number?)
	const Data = GetData(Profile)
	const Timestamp = Now or os.time()

	Data.Quests = Data.Quests or {}
	Data.QuestCycles = Data.QuestCycles or {
		DailyStart = Timestamp,
		WeeklyStart = Timestamp,
	}

	if (Data.QuestCycles.DailyStart or 0) <= 0 then
		Data.QuestCycles.DailyStart = Timestamp
	end
	if (Data.QuestCycles.WeeklyStart or 0) <= 0 then
		Data.QuestCycles.WeeklyStart = Timestamp
	end

	const ResetDaily = Timestamp - Data.QuestCycles.DailyStart >= QuestOptions.DailyCooldown
	const ResetWeekly = Timestamp - Data.QuestCycles.WeeklyStart >= QuestOptions.WeeklyCooldown

	if ResetDaily then
		Data.QuestCycles.DailyStart = Timestamp
	end
	if ResetWeekly then
		Data.QuestCycles.WeeklyStart = Timestamp
	end

	const Definitions = QuestOptions.Definitions
	for Index = 1, #Definitions do
		const Definition = Definitions[Index]
		if (ResetDaily and Definition.category == "Daily") or (ResetWeekly and Definition.category == "Weekly") then
			Data.Quests[Definition.id] = nil
		end
		Data.Quests[Definition.id] = Data.Quests[Definition.id] or QuestOptions.createProgress()
	end
end

function QuestProgression.getTimers(Profile: any, Now: number?): (number, number)
	const Data = GetData(Profile)
	const Timestamp = Now or os.time()
	QuestProgression.ensure(Profile, Timestamp)

	const Cycles = Data.QuestCycles
	return math.max(0, ((Cycles.DailyStart or Timestamp) + QuestOptions.DailyCooldown) - Timestamp),
		math.max(0, ((Cycles.WeeklyStart or Timestamp) + QuestOptions.WeeklyCooldown) - Timestamp)
end

function QuestProgression.addProgress(Profile: any, Metric: string, Amount: number): boolean
	QuestProgression.ensure(Profile)

	const Data = GetData(Profile)
	const Definitions = QuestOptions.ById
	local Changed = false

	for QuestId, Definition in next, Definitions do
		if Definition.metric ~= Metric then
			continue
		end

		const Quest = Data.Quests[QuestId]
		if Quest.Claimed then
			continue
		end

		const NextProgress = math.clamp((Quest.Progress or 0) + Amount, 0, Definition.goal)
		if NextProgress ~= Quest.Progress then
			Quest.Progress = NextProgress
			Quest.Completed = Quest.Progress >= Definition.goal
			Changed = true
		end
	end

	return Changed
end

function QuestProgression.prepareClaim(Profile: any, QuestId: string): (boolean, string, any?)
	const Definition = QuestOptions.ById[QuestId]
	if not Definition then
		return false, "Quest unavailable.", nil
	end

	QuestProgression.ensure(Profile)
	const Quest = GetData(Profile).Quests[QuestId]
	if Quest.Claimed then
		return false, "Already claimed.", nil
	end
	if not Quest.Completed then
		return false, "Quest is not finished yet.", nil
	end

	Quest.Claimed = true
	return true, "Quest reward claimed.", Definition
end

return QuestProgression
