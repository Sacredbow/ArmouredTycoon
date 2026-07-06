--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestOptions = require(ReplicatedStorage.Progression.Quests.QuestOptions)

local QuestProgression = {}

local function getData(profile: any): any
	return profile.Data
end

function QuestProgression.ensure(profile: any, now: number?)
	local data = getData(profile)
	local timestamp = now or os.time()

	data.Quests = data.Quests or {}
	data.QuestCycles = data.QuestCycles or {
		DailyStart = timestamp,
		WeeklyStart = timestamp,
	}

	if (data.QuestCycles.DailyStart or 0) <= 0 then
		data.QuestCycles.DailyStart = timestamp
	end
	if (data.QuestCycles.WeeklyStart or 0) <= 0 then
		data.QuestCycles.WeeklyStart = timestamp
	end

	local resetDaily = timestamp - data.QuestCycles.DailyStart >= QuestOptions.DailyCooldown
	local resetWeekly = timestamp - data.QuestCycles.WeeklyStart >= QuestOptions.WeeklyCooldown

	if resetDaily then
		data.QuestCycles.DailyStart = timestamp
	end
	if resetWeekly then
		data.QuestCycles.WeeklyStart = timestamp
	end

	for questId, definition in pairs(QuestOptions.ById) do
		if (resetDaily and definition.category == "Daily") or (resetWeekly and definition.category == "Weekly") then
			data.Quests[questId] = nil
		end

		data.Quests[questId] = data.Quests[questId] or QuestOptions.createProgress()
	end
end

function QuestProgression.getTimers(profile: any, now: number?): (number, number)
	local data = getData(profile)
	local timestamp = now or os.time()
	QuestProgression.ensure(profile, timestamp)

	local cycles = data.QuestCycles
	return math.max(0, ((cycles.DailyStart or timestamp) + QuestOptions.DailyCooldown) - timestamp),
		math.max(0, ((cycles.WeeklyStart or timestamp) + QuestOptions.WeeklyCooldown) - timestamp)
end

function QuestProgression.addProgress(profile: any, metric: string, amount: number): boolean
	QuestProgression.ensure(profile)

	local data = getData(profile)
	local changed = false
	for questId, definition in pairs(QuestOptions.ById) do
		if definition.metric ~= metric then
			continue
		end

		local quest = data.Quests[questId]
		if quest.Claimed then
			continue
		end

		local nextProgress = math.clamp((quest.Progress or 0) + amount, 0, definition.goal)
		if nextProgress ~= quest.Progress then
			quest.Progress = nextProgress
			quest.Completed = quest.Progress >= definition.goal
			changed = true
		end
	end

	return changed
end

function QuestProgression.prepareClaim(profile: any, questId: string): (boolean, string, any?)
	local definition = QuestOptions.ById[questId]
	if not definition then
		return false, "Quest unavailable.", nil
	end

	QuestProgression.ensure(profile)
	local quest = getData(profile).Quests[questId]
	if quest.Claimed then
		return false, "Already claimed.", nil
	end
	if not quest.Completed then
		return false, "Quest is not finished yet.", nil
	end

	quest.Claimed = true
	return true, "Quest reward claimed.", definition
end

return QuestProgression
