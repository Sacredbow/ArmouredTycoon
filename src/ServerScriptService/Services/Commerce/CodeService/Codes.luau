--!strict
--[[
	@class Codes

	@desc
	Server-authoritative code definitions for CodeService.

	Each code declares a Reward table and its own ExpiresAt (unix timestamp).
	A global cap (GlobalExpirySeconds) bounds every code as a fallback so no
	code can outlive the server's global code window. All times are unix via
	os.time() (never tick()).
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

--// Global expiry window (seconds).
-- Applied to any code without an explicit ExpiresAt, and serves as a hard
-- cap on every code regardless of its individual expiry.
const GlobalExpirySeconds = 7 * 24 * 60 * 60 -- 7 days

--// Reference point for the global expiry window (unix timestamp at boot).
local ReferenceTime = os.time()

--// Code definitions

-- Edit ExpiresAt per code using unix timestamps, e.g.:
--   ExpiresAt = os.time() + (2 * 24 * 60 * 60), -- 2 days from server boot
local CODES: { [string]: CodeDefinition } = {
	R3L3ASE = {
		Reward = { Cash = 5000 },
		
	},
	FR33MULTI = {
		Reward = { Multiplier = 1.5 },
	},
	STARTER = {
		Reward = { Cash = 10000 },
		-- ExpiresAt = os.time() + (1 * 24 * 60 * 60), -- 1 day from boot
	},
}

--// Public API

-- Returns the effective expiry (unix timestamp) for a code:
-- the minimum of its own ExpiresAt and the global expiry cap.
function GetEffectiveExpiry(CodeName: string): number
	local Definition = CODES[CodeName]
	if not Definition then
		return 0
	end

	local GlobalExpiry = ReferenceTime + GlobalExpirySeconds
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
	GlobalExpirySeconds = GlobalExpirySeconds,
	GetEffectiveExpiry = GetEffectiveExpiry,
	IsExpired = IsExpired,
	GetCode = GetCode,
}
