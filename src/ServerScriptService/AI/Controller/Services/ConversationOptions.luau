--!strict

local ConversationOptions = {}

export type Option = {
	id: string,
	text: string,
	tone: string,
}

export type Response = {
	line: string,
	endConversation: boolean,
	avoidMode: string?,
}

local QUOTE_TOPICS = {
	"this place",
	"your patrol",
	"the noise around here",
	"the people passing through",
	"the safest way through",
	"what happened earlier",
	"the weirdest thing you saw today",
	"why everyone looks tense",
	"whether anything changed nearby",
	"where you are headed",
	"how your shift is going",
	"whether I should be worried",
	"who usually causes trouble here",
	"what I should avoid",
	"whether the area is calm",
	"why you keep watching the road",
	"whether you need help",
	"how long you have been out here",
}

local SCENE_DETAILS = {
	"the road has been too quiet",
	"someone was running earlier",
	"that corner feels watched",
	"the lights keep flickering",
	"people keep cutting through here",
	"the guards look tense",
	"the air feels weird today",
	"I heard shouting a minute ago",
	"someone dropped tools near the path",
	"that door has been open too long",
	"people keep avoiding this area",
	"there is fresh damage nearby",
	"the machines sound different",
	"someone left in a hurry",
	"the patrol route looks longer today",
	"that alley is way too quiet",
	"nobody is making eye contact",
	"the whole place feels off",
	"someone keeps watching from far away",
	"the usual path is blocked",
	"there are footprints everywhere",
	"that noise keeps coming back",
	"people are pretending nothing happened",
	"someone is hiding something",
	"the timing feels suspicious",
	"everyone suddenly got busy",
	"that shortcut looks unsafe",
	"the workers stopped talking",
	"the area emptied out fast",
	"your route looks different today",
}

local PLAYER_INTENTS = {
	"should I keep moving?",
	"did you see what caused it?",
	"am I walking into trouble?",
	"do you know who was involved?",
	"would you avoid it if you were me?",
	"is that normal around here?",
	"should someone check it out?",
	"are people safe?",
	"did anyone get hurt?",
	"do you want backup?",
}

local FRIENDLY_QUOTES = {
	"Hey, you alright out here?",
	"You look like you have had a long walk. Need anything?",
	"I am not trying to bother you, just checking in.",
	"That route looks rough. How are you holding up?",
	"I have got a second if you want to talk.",
	"Appreciate you keeping an eye on things.",
	"Anything I should know before I keep moving?",
	"You seem calm. That is rare around here.",
	"I will stay out of your way. Quick question though.",
	"Looks like you know this place better than me.",
	"Hope nobody has been giving you trouble.",
	"Mind if I ask what you saw back there?",
	"Thanks for not immediately acting like I am a problem.",
	"I am just passing through, promise.",
	"You ever get a quiet day out here?",
	"Tell me the truth, is this route always this strange?",
	"I respect the hustle. You have been walking all day?",
	"You look like someone who notices everything.",
}

local NEUTRAL_QUOTES = {
	"What are you doing around here?",
	"Have you seen anything unusual?",
	"Which way are you heading?",
	"Do you know what happened nearby?",
	"Is this area usually safe?",
	"Why is everyone acting tense today?",
	"Can you point me in the right direction?",
	"What is the fastest way through here?",
	"Have you seen anyone suspicious?",
	"Do people bother you often?",
	"Are you supposed to patrol this whole area?",
	"Do you know who runs this place?",
	"Is there something I should be watching for?",
	"How long have you been walking this route?",
	"Did you hear that noise earlier?",
	"Are people usually this jumpy around here?",
	"Do you think things are getting worse?",
	"Are you heading somewhere important?",
}

local ABRASIVE_QUOTES = {
	"Why are you staring at me like that?",
	"You got a problem, or are you just standing there?",
	"Calm down. I asked one question.",
	"You are acting like I ruined your whole day.",
	"Do you always walk away when someone talks?",
	"I need an answer, not attitude.",
	"Stop pretending you did not hear me.",
	"You are making this harder than it has to be.",
	"I am not chasing you for basic information.",
	"Why are you so nervous?",
	"Do not get weird. Just answer the question.",
	"You could be helpful for once.",
	"Back up? I am barely near you.",
	"Are you always this dramatic?",
	"You look guilty. Should I know why?",
	"That silence is not helping you.",
	"Quit dodging the question.",
	"You are terrible at acting normal.",
}

local FOLLOW_UP_QUOTES = {
	"What do you mean by that?",
	"Can you explain that a little more?",
	"That sounds important. What happened next?",
	"Why would someone do that?",
	"So what would you do if you were me?",
	"Are you sure about that?",
	"Who told you that?",
	"Does that happen often?",
	"That is oddly specific. How do you know?",
	"Should I be worried about it?",
	"What made you notice that?",
	"Is that why people keep looking over here?",
}

local ACTION_OPTIONS = {
	"Ask them to explain a little more.",
	"Ask if they are sure.",
	"Ask what happened before you arrived.",
	"Ask if they have advice.",
	"Ask what would make their day easier.",
	"Ask if they have heard any rumors.",
	"Ask what they would do next.",
	"Give them space and listen.",
	"Step aside so they can keep moving.",
}

local CONTEXT_QUOTES = {
	Happy = {
		"Thanks for telling me. What should I watch for?",
		"That makes sense. I will keep my distance.",
		"I appreciate the heads up. Anything else I should know?",
		"Alright, I trust you. Where would you go from here?",
		"Good to know. I am trying not to cause trouble.",
		"That is actually helpful. What happened before that?",
		"I hear you. I will be careful around here.",
		"Fair enough. You seem like you know what is going on.",
	},
	Normal = {
		"Alright, what should I do next?",
		"That sounds like something I should avoid.",
		"So this is normal around here?",
		"Can you be more specific?",
		"Should I keep moving or wait?",
		"Who else knows about this?",
		"That does not sound great. Is anyone handling it?",
		"I get it. Just give me the short version.",
	},
	FollowUp = {
		"What do you mean by that?",
		"Can you explain that a little more?",
		"That sounds important. What happened next?",
		"Why would someone do that?",
		"So what would you do if you were me?",
		"Are you sure about that?",
		"Who told you that?",
		"Does that happen often?",
	},
	Rude = {
		"That answer tells me almost nothing.",
		"You are dodging the question.",
		"Stop being vague and just say it.",
		"I do not have time for half answers.",
		"You clearly know more than you are saying.",
		"That is not helpful.",
		"Do you always make simple questions difficult?",
		"Try again, but actually answer this time.",
	},
}

local GOODBYES = {
	"Say bye and let them get on with their day.",
	"Tell them to stay safe and end the conversation.",
	"Step aside and let them continue.",
	"Wish them a calm shift and leave.",
	"Say you will not hold them up.",
	"End the chat politely.",
	"Tell them you are heading out.",
	"Say thanks and move on.",
}

local RESPONSE_LINES = {
	Happy = {
		"That's kind of you to ask. Most people just walk straight past.",
		"Not a bad day so far. I am hoping it stays that way.",
		"I appreciate the politeness. It makes the route easier.",
		"Nothing too strange yet, which is exactly how I like it.",
		"You seem alright. Just keep your eyes open out here.",
		"I have seen quieter days, but this one will do.",
		"Thanks. A little respect goes a long way.",
		"Honestly, I am just glad nobody is shouting right now.",
		"Safe enough if people keep their heads on straight.",
		"That is a decent question. Most trouble starts when people rush.",
		"You ask like a normal person, so sure, I can talk for a second.",
		"Most folks only talk when they want something. You seem different.",
		"I do need to keep moving, but I can spare a moment.",
		"If everyone asked like that, this job would be easier.",
		"I noticed a few things, but nothing I would panic over.",
	},
	Normal = {
		"I can answer, but I do need to keep moving.",
		"Nothing unusual. That is usually good news.",
		"I am working my route. Simple as that.",
		"If you need directions, ask quick.",
		"People have been restless today. I would stay alert.",
		"I do not mind a question, but do not crowd me.",
		"Most of what I see is ordinary until someone makes it worse.",
		"I am not trying to be rude. I just have a job to do.",
		"Keep it brief and we are fine.",
		"There is always something happening if you look hard enough.",
		"I heard something earlier, but I am not paid to investigate mysteries.",
		"Just stay aware. That solves half the problems around here.",
		"I have seen people act stranger for less.",
		"You want my advice? Do not stand in anyone's way too long.",
		"Could be nothing. Could be trouble. Around here those look similar.",
	},
	Abrasive = {
		"I said what I said. Do not make this difficult.",
		"You are really testing my patience.",
		"I am not in the mood to explain myself twice.",
		"Back up a little. I mean it.",
		"You are making this feel like a problem.",
		"I do not owe every stranger a full conversation.",
		"Try being less pushy next time.",
		"I am walking away before this gets worse.",
		"That tone is not helping you.",
		"We are done if you keep acting like that.",
		"I was calm until you made it weird.",
		"People like you are exactly why I keep moving.",
		"No, I am not doing this all day.",
		"You can ask again when you remember manners.",
		"I am choosing peace, and that means leaving.",
	},
}

local END_LINES = {
	"Alright. Take care.",
	"Good. I need to keep moving.",
	"Thanks. Stay safe out there.",
	"Fine by me. I am heading on.",
	"Appreciated. Have a decent day.",
	"That works. I will get back to it.",
	"No problem. I will keep moving.",
	"Good talk. Do not stand around too long.",
}

local QUIT_LINES = {
	"No. I am done talking.",
	"That is enough. Move along.",
	"You had your chance to be normal.",
	"I am leaving before this gets worse.",
	"Do not follow me.",
	"We are done here.",
	"Absolutely not. I am out.",
	"You made that easy to end.",
}

local ALL_QUOTES: { Option } = {}

local function addOption(text: string, tone: string)
	table.insert(ALL_QUOTES, {
		id = `{tone}:{#ALL_QUOTES + 1}`,
		text = text,
		tone = tone,
	})
end

local function addQuotePool(pool: { string }, tone: string)
	for _, quote in pool do
		addOption(`"{quote}"`, tone)
	end
end

addQuotePool(FRIENDLY_QUOTES, "Happy")
addQuotePool(NEUTRAL_QUOTES, "Normal")
addQuotePool(ABRASIVE_QUOTES, "Rude")
addQuotePool(FOLLOW_UP_QUOTES, "FollowUp")

for _, topic in QUOTE_TOPICS do
	addOption(`"Can I ask you about {topic}?"`, "Normal")
	addOption(`"Be honest with me about {topic}."`, "FollowUp")
	addOption(`"I hope {topic} has not been giving you trouble."`, "Happy")
	addOption(`"Stop dodging questions about {topic}."`, "Rude")
end

for _, detail in SCENE_DETAILS do
	for _, intent in PLAYER_INTENTS do
		addOption(`"I noticed {detail}; {intent}"`, "Normal")
		addOption(`"Not trying to start anything, but {detail}; {intent}"`, "Happy")
		addOption(`"You saw that {detail}; {intent}"`, "FollowUp")
	end
end

local function pick<T>(items: { T }): T
	return items[math.random(1, #items)]
end

local function quoteMatchesDisposition(option: Option, disposition: string): boolean
	if option.tone == "FollowUp" then
		return true
	end
	if disposition == "Abrasive" then
		return option.tone == "Rude" or option.tone == "Normal"
	end
	return option.tone == disposition or option.tone == "Normal"
end

local function pickQuote(disposition: string, allowRude: boolean): Option
	for _ = 1, 100 do
		local option = pick(ALL_QUOTES)
		if quoteMatchesDisposition(option, disposition) and (allowRude or option.tone ~= "Rude") then
			return option
		end
	end

	return pick(ALL_QUOTES)
end

function ConversationOptions.GetOptionCount(): number
	return #ALL_QUOTES + #ACTION_OPTIONS + #GOODBYES
end

function ConversationOptions.GetOptions(disposition: string, turnCount: number): { Option }
	local firstTone = if disposition == "Happy" then "Happy" else "Normal"
	local first = {
		id = `{firstTone}:context:{math.random(1, 1000000)}`,
		text = `"{pick(CONTEXT_QUOTES[firstTone])}"`,
		tone = firstTone,
	}
	local allowRude = disposition == "Abrasive" or turnCount >= 2 or math.random() < 0.18
	local secondTone = if allowRude then "Rude" elseif turnCount == 0 then "Normal" else "FollowUp"
	local second = {
		id = `{secondTone}:context:{math.random(1, 1000000)}`,
		text = `"{pick(CONTEXT_QUOTES[secondTone])}"`,
		tone = secondTone,
	}

	local actionText = if turnCount >= 2 or math.random() < 0.35 then pick(GOODBYES) else pick(ACTION_OPTIONS)
	local actionTone = if table.find(GOODBYES, actionText) then "Goodbye" else "FollowUp"

	return {
		first,
		second,
		{
			id = `{actionTone}:{math.random(1, 1000000)}`,
			text = actionText,
			tone = actionTone,
		},
	}
end

function ConversationOptions.GetResponse(disposition: string, optionTone: string, turnCount: number): Response
	if optionTone == "Goodbye" then
		return {
			line = pick(END_LINES),
			endConversation = true,
		}
	end

	if optionTone == "Rude" then
		return {
			line = pick(QUIT_LINES),
			endConversation = true,
			avoidMode = if disposition == "Abrasive" or turnCount >= 3 then "Flee" else "Sidestep",
		}
	end

	local responseDisposition = if disposition == "Happy"
		then "Happy"
		elseif disposition == "Abrasive" then "Abrasive"
		else "Normal"
	return {
		line = pick(RESPONSE_LINES[responseDisposition]),
		endConversation = turnCount >= 7,
	}
end

return ConversationOptions
