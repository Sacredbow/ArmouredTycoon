--!strict
--[[
	@class Codes

	@desc
	Server-authoritative code definitions for CodeService.

	Each code has a reward and may have its own absolute expiry. A shared
	seven-day window starts at the first live server boot for this campaign.
	The campaign start is stored durably and reused after server restarts.
]]

--// Types

export type CodeReward = {
	Cash: number?,
	Emerald: number?,
	Multiplier: number?,
	Rebirths: number?,
}

export type CodeDefinition = {
	Reward: CodeReward,
	ExpiresAt: number?,
}

--// Loaded from a durable DataStore marker by CodeService after the release starts.
--// Codes stay unavailable until the marker is loaded.
local CampaignStartUnix = 0
const GlobalExpirySeconds = 7 * 24 * 60 * 60

--// Code definitions
local CODES: { [string]: CodeDefinition } = {
	R3L3ASE = {
		Reward = { Cash = 5000 },
	},
	FR33MULTI = {
		Reward = { Multiplier = 1.5 },
	},
	STARTER = {
		Reward = { Cash = 10000 },
	},
}

--// Public API

-- Returns the effective expiry (unix timestamp) for a code:
-- the minimum of its own ExpiresAt and the global expiry cap.
function SetCampaignStartUnix(value: number)
	assert(value > 0 and value == math.floor(value), "Campaign start must be a positive Unix timestamp")
	CampaignStartUnix = value
end

function GetEffectiveExpiry(CodeName: string): number
	local Definition = CODES[CodeName]
	if not Definition then
		return 0
	end

	local GlobalExpiry = if CampaignStartUnix > 0 then CampaignStartUnix + GlobalExpirySeconds else 0
	local CodeExpiry = Definition.ExpiresAt or math.huge

	return math.min(CodeExpiry, GlobalExpiry)
end

function IsExpired(CodeName: string): boolean
	return os.time() >= GetEffectiveExpiry(CodeName)
end

function GetCode(CodeName: string): CodeDefinition?
	return CODES[CodeName]
end

return {
	CODES = CODES,
	SetCampaignStartUnix = SetCampaignStartUnix,
	IsCampaignReady = function(): boolean return CampaignStartUnix > 0 end,
	GlobalExpirySeconds = GlobalExpirySeconds,
	GetEffectiveExpiry = GetEffectiveExpiry,
	IsExpired = IsExpired,
	GetCode = GetCode,
}
