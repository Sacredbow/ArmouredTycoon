--!strict
--[[
	@class QuestOptions

	@desc
	Central quest registry aggregating all difficulty tiers
	(Normal / Medium / Hard) into a single lookup table.
]]

--// Modules

const NormalQuests = require(script.NormalQuests)
const MediumQuests = require(script.MediumQuests)
const HardQuests = require(script.HardQuests)

--// Types

export type QuestCategory = "Daily" | "Weekly"

export type QuestDifficulty = "Normal" | "Medium" | "Hard"

export type QuestDefinition = {
	id: string,
	category: QuestCategory,
	difficulty: QuestDifficulty,
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

--// Module

local QuestOptions = {
	DailyCooldown = 24 * 60 * 60,
	WeeklyCooldown = 7 * 24 * 60 * 60,
}

--// Aggregate Definitions

local AllDefinitions: { QuestDefinition } = {}

-- Inline definition appending to avoid forward-reference issues
local function AppendDefinition(Def: any, Difficulty: QuestDifficulty)
	table.insert(AllDefinitions, {
		id = Def.id,
		category = Def.category,
		difficulty = Difficulty,
		title = Def.title,
		subtitle = Def.subtitle,
		metric = Def.metric,
		goal = Def.goal,
		reward = Def.reward,
		rewardCash = Def.rewardCash,
		rewardEmerald = Def.rewardEmerald,
		rewardExperience = Def.rewardExperience,
		accent = Def.accent,
	})
end

for Index = 1, #NormalQuests do
	AppendDefinition(NormalQuests[Index], "Normal")
end
for Index = 1, #MediumQuests do
	AppendDefinition(MediumQuests[Index], "Medium")
end
for Index = 1, #HardQuests do
	AppendDefinition(HardQuests[Index], "Hard")
end

QuestOptions.Definitions = AllDefinitions

--// Lookup Tables

QuestOptions.ById = {}
for Index = 1, #AllDefinitions do
	QuestOptions.ById[AllDefinitions[Index].id] = AllDefinitions[Index]
end

QuestOptions.ByDifficulty = {
	Normal = {},
	Medium = {},
	Hard = {},
}

for Index = 1, #AllDefinitions do
	QuestOptions.ByDifficulty[AllDefinitions[Index].difficulty][AllDefinitions[Index].id] = AllDefinitions[Index]
end

--// Public API

function QuestOptions.createProgress(): QuestProgress
	return {
		Progress = 0,
		Completed = false,
		Claimed = false,
	}
end

function QuestOptions.createProgressMap(category: QuestCategory?, difficulty: QuestDifficulty?): { [string]: QuestProgress }
	local progressByQuestId = {}
	for Index = 1, #AllDefinitions do
		const Definition = AllDefinitions[Index]
		if category ~= nil and Definition.category ~= category then
			continue
		end
		if difficulty ~= nil and Definition.difficulty ~= difficulty then
			continue
		end
		progressByQuestId[Definition.id] = QuestOptions.createProgress()
	end

	return progressByQuestId
end

return QuestOptions
