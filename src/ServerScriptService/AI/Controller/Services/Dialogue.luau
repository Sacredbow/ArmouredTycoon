--!strict

local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Core.Types)
local WorldQuery = require(script.Parent.WorldQuery)

type AIContext = Types.AIContext
type Disposition = Types.Disposition

local Dialogue = {}

local function buildLines(openers: { string }, closers: { string }): { string }
	local lines = {}
	for _, opener in openers do
		for _, closer in closers do
			table.insert(lines, `{opener} {closer}`)
		end
	end
	return lines
end

local HAPPY_LINES = buildLines({
	"Hey there.",
	"Nice to see you.",
	"Good to see a friendly face.",
	"Morning, traveler.",
	"Hello there.",
	"Well, hey.",
	"Glad you're around.",
	"You're looking lively.",
	"Ah, company.",
	"Good timing.",
}, {
	"Hope the day is treating you well.",
	"Try not to get into trouble.",
	"Keep your head up out there.",
	"Stay safe on the road.",
	"You're welcome to walk with me a moment.",
	"Looks like a fine day for a patrol.",
	"Take care of yourself out there.",
	"I don't mind the company.",
	"Things seem calmer with you around.",
	"Let me know if you spot anything odd.",
	"Hope the rest of your day stays easy.",
	"You seem alright. Keep it that way.",
	"Try to keep your boots clean out there.",
	"Not every passerby gets a smile from me.",
	"You're doing fine so far.",
})

local NORMAL_LINES = buildLines({
	"Yeah?",
	"Need something?",
	"Can I help you?",
	"You good?",
	"What is it?",
	"Something on your mind?",
	"You trying to get my attention?",
	"Everything alright?",
	"What's going on?",
	"Do you need me for something?",
}, {
	"I'm in the middle of my route.",
	"Make it quick, alright?",
	"I've still got work to do.",
	"Try to keep this brief.",
	"If it's important, say it now.",
	"I can spare a second.",
	"Just don't block the path.",
	"I'd rather keep moving.",
	"I'm listening, for a moment.",
	"Let's not make this complicated.",
	"I've got a schedule to keep.",
	"I don't love being interrupted.",
	"Best make this worth the pause.",
	"Go on, then.",
	"I'm not stopping twice for the same thing.",
})

local ABRASIVE_LINES = buildLines({
	"What do you want?",
	"You again?",
	"Oh, for goodness' sake.",
	"Seriously?",
	"Still here?",
	"Can you not?",
	"I'm losing patience.",
	"Move along.",
	"You're pushing it.",
	"This again?",
}, {
	"You're wasting my time.",
	"Back off and let me work.",
	"I'm not here for your entertainment.",
	"Find someone else to bother.",
	"I have better things to do.",
	"Stop hovering over me.",
	"You're wearing thin.",
	"You're a problem I don't need.",
	"Take the hint and leave.",
	"Don't test me again.",
	"I'm one more interruption from being unpleasant.",
	"You're making yourself very hard to like.",
	"This patience isn't endless.",
	"I am trying very hard not to snap at you.",
	"You are not improving this moment.",
})

local FOLLOW_UP_LINES = {
	"Need something?",
	"You're still following me?",
	"Did you need help, or are you just lingering?",
	"You're back already?",
	"Do you actually want something?",
	"You're making this feel deliberate.",
	"Can I do something for you, or not?",
	"You're awfully persistent.",
	"This is the second time now.",
	"Say what you need and say it quick.",
	"You're turning this into a habit.",
	"We already did this once.",
}

local DUO_FRIENDLY_LINES = {
	"Need something, you two?",
	"Alright then, what's going on here?",
	"You both trying to tell me something?",
	"Well, I've got an audience now.",
	"What do you two need from me?",
	"If both of you are here, make it quick.",
	"You two look like you're about to ask for something.",
	"Alright, both of you, what is it?",
}

local DUO_ABRASIVE_LINES = {
	"What do you two want?",
	"Both of you, back off.",
	"Wonderful. There's two of you now.",
	"Don't crowd me, either of you.",
	"I don't have time for a group meeting.",
	"If you're both here to bother me, save it.",
	"Two of you and still no good reason to be here.",
	"I'm not in the mood for either of you.",
}

local ESCALATION_LINES = {
	"Alright, that's enough. Back off.",
	"I'm done being patient with you.",
	"Keep this up and I'm not being polite anymore.",
	"That's the limit. Leave me alone.",
	"You've officially worn out my patience.",
	"Right. That's enough out of you.",
	"One more time and we're done being civil.",
}

local IDLE_BLOCK_LINES = {
	"Can you please not be in the way?",
	"You're blocking the path.",
	"Need you to shift a little.",
	"Could you not stand there, please?",
	"I need to get by.",
	"Bit of room, please.",
	"You're right in the way.",
	"Can you step aside for me?",
	"I've got to get past.",
	"Please don't plant yourself in the walkway.",
	"Standing there is not helping either of us.",
	"Could you stop being a roadblock for a second?",
	"You're making this harder than it needs to be.",
	"I really need that space you're occupying.",
}

local ARMED_LINES = {
	"Easy. Let's keep this calm.",
	"No sudden moves, alright?",
	"Take a breath. Nobody needs trouble.",
	"Let's all relax for a second.",
	"Keep that pointed somewhere else.",
	"We can calm this down.",
	"Let's not make this worse.",
	"Nobody has to get hurt here.",
	"Just stay calm and lower the tension.",
	"Take it easy. We don't need a scene.",
	"I don't want trouble with an armed stranger.",
	"Let's both make smart choices right now.",
	"Keep it steady and nobody panics.",
	"Maybe lower the weapon and we can both move on.",
	"I'm backing up, you stay calm.",
}

local DAMAGE_LINES = {
	"Oh my God!",
	"What was that?",
	"I'm hit!",
	"Easy, easy!",
	"Hey! Watch it!",
	"I don't want trouble!",
	"Back off!",
	"What is wrong with you?",
	"Somebody help!",
	"This is bad!",
	"I didn't do anything!",
	"Please stop!",
	"No, no, no!",
	"Someone saw that, right?",
	"I'm not staying here!",
}

local function pickLine(context: AIContext, lines: { string }): string
	if #lines == 1 then
		return lines[1]
	end

	local choice = lines[math.random(1, #lines)]
	if choice == context.LastSpokenLine then
		for _, line in lines do
			if line ~= context.LastSpokenLine then
				choice = line
				break
			end
		end
	end

	return choice
end

local function getPlayerUserIdFromRoot(root: BasePart?): number
	if not root then
		return 0
	end

	local character = root.Parent
	if not character or not character:IsA("Model") then
		return 0
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return 0
	end

	return player.UserId
end

local function updateDisposition(context: AIContext, now: number)
	if context.Disposition == "Abrasive" and now >= context.AbrasiveUntil then
		context.Disposition = "Normal"
		context.AbrasiveUntil = 0
		context.RepeatInteractionCount = 0
	end
end

local function chooseFriendlyLineForContext(context: AIContext, disposition: Disposition): string
	if disposition == "Happy" then
		return pickLine(context, HAPPY_LINES)
	end

	return pickLine(context, NORMAL_LINES)
end

function Dialogue.PrepareObservation(context: AIContext, targets: { BasePart }): boolean
	local primaryTarget = targets[1]
	if not primaryTarget then
		return false
	end

	local now = os.clock()
	updateDisposition(context, now)

	local secondaryTarget = targets[2]
	local primaryUserId = getPlayerUserIdFromRoot(primaryTarget)

	if
		primaryUserId ~= 0
		and context.LastInteractionUserId == primaryUserId
		and now - context.LastInteractionTime <= context.Config.RepeatInteractionWindow
	then
		context.RepeatInteractionCount += 1
	else
		context.LastInteractionUserId = primaryUserId
		context.RepeatInteractionCount = 0
	end

	context.LastInteractionTime = now
	context.ObservationTarget = primaryTarget
	context.ObservationSecondaryTarget = secondaryTarget
	context.ObservationLookPosition = if secondaryTarget
		then (primaryTarget.Position + secondaryTarget.Position) * 0.5
		else primaryTarget.Position
	context.ObservationHoldDuration = context.Config.ObservationDuration
	context.ObservationShouldWave = false
	context.ObservationShouldAvoidAfter = true
	context.ObservationAvoidMode = "Sidestep"

	if context.RepeatInteractionCount >= 2 then
		context.Disposition = "Abrasive"
		context.AbrasiveUntil = now + context.Config.AbrasiveRecoveryDuration
	end

	local targetIsArmed = WorldQuery.IsPlayerArmed(primaryTarget)
	local targetIsIdle = WorldQuery.IsPlayerIdle(primaryTarget)

	if targetIsArmed then
		context.ObservationLine = pickLine(context, ARMED_LINES)
		context.ObservationShouldAvoidAfter = true
		context.ObservationAvoidMode = "Backpedal"
		context.ObservationShouldWave = false
		return true
	end

	if targetIsIdle then
		context.ObservationLine = pickLine(context, IDLE_BLOCK_LINES)
		context.ObservationShouldAvoidAfter = true
		context.ObservationHoldDuration = 0
		context.ObservationShouldWave = false
		context.ObservationAvoidMode = "Sidestep"
		return true
	end

	if context.Disposition == "Abrasive" then
		if secondaryTarget then
			context.ObservationLine = pickLine(context, DUO_ABRASIVE_LINES)
		elseif context.RepeatInteractionCount >= 2 then
			context.ObservationLine = pickLine(context, ESCALATION_LINES)
		else
			context.ObservationLine = pickLine(context, ABRASIVE_LINES)
		end

		context.ObservationShouldAvoidAfter = false
	elseif secondaryTarget then
		context.ObservationLine = pickLine(context, DUO_FRIENDLY_LINES)
	elseif context.RepeatInteractionCount == 1 then
		context.ObservationLine = pickLine(context, FOLLOW_UP_LINES)
	else
		context.ObservationLine = chooseFriendlyLineForContext(context, context.Disposition)
		context.ObservationShouldWave = context.Disposition == "Happy"
	end

	context.IgnoreObservationUntil = now + context.Config.ObservationIgnoreDuration
	return true
end

function Dialogue.GetDamageReactionLine(context: AIContext): string
	return pickLine(context, DAMAGE_LINES)
end

function Dialogue.GetArmedReactionLine(context: AIContext): string
	return pickLine(context, ARMED_LINES)
end

return Dialogue
