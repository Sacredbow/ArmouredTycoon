--!strict
--[[
	@class CodeService

	@desc
	Handles in-game code redemption. Code definitions and expiry live in the
	child Codes module; redeemed codes are persisted in the player's
	ProfileStore profile (Profile.Data.RedeemedCodes) rather than a standalone
	DataStore. All timestamps are unix via os.time().
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const Packets = require(ReplicatedStorage.Network.Packets)
const Codes = require(script.Codes)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

--// Module

local CodeService: { [string]: any } = {}
CodeService.__index = CodeService

--// Constructor

function CodeService.new(): any
	return setmetatable({}, CodeService)
end

--// Internal Methods

-- Returns the player's redeemed codes map (code -> unix timestamp).
-- Returns nil when the profile isn't loaded yet (redeem should be deferred).
-- Self-heals a corrupt non-table RedeemedCodes field instead of erroring.
function CodeService:_GetRedeemedCodes(Player: Player): { [string]: number }?
	local profile = ProfileManager.Profiles[Player]
	if not profile then
		return nil
	end

	local redeemed = profile.Data.RedeemedCodes
	if type(redeemed) ~= "table" then
		warn(`[CodeService] Repairing corrupt RedeemedCodes for {Player.Name}`)
		redeemed = {}
	end

	profile.Data.RedeemedCodes = redeemed
	return redeemed
end

-- Applies a code's reward table to the player.
function CodeService:_ApplyReward(Player: Player, Reward: any)
	if typeof(Reward) ~= "table" then
		return
	end

	local Cash = Reward.Cash
	if typeof(Cash) == "number" and Cash > 0 then
		ProfileManager.AddCash(Player, Cash)
	end

	local Emerald = Reward.Emerald
	if typeof(Emerald) == "number" and Emerald > 0 then
		ProfileManager.AddEmerald(Player, Emerald)
	end

	local Rebirths = Reward.Rebirths
	if typeof(Rebirths) == "number" and Rebirths > 0 then
		ProfileManager.AddRebirths(Player, Rebirths)
	end

	local Multiplier = Reward.Multiplier
	if typeof(Multiplier) == "number" then
		local Current = PlayerRuntimeState.GetMultiplier(Player)
		PlayerRuntimeState.SetMultiplier(Player, math.max(Current, Multiplier))
	end
end

function CodeService:_Redeem(Player: Player, CodeInput: string): (boolean, string)
	if typeof(CodeInput) ~= "string" or #CodeInput > 64 then
		warn(`[CodeService] {Player.Name} submitted invalid code (not string or >64 chars)`)
		return false, "Invalid Code"
	end

	CodeInput = string.upper(string.gsub(CodeInput, "%s+", ""))

	if CodeInput == "" then
		return false, "Empty Code"
	end

	local Definition = Codes.GetCode(CodeInput)
	if not Definition then
		return false, "Invalid Code"
	end

	if Codes.IsExpired(CodeInput) then
		return false, "Code Expired"
	end

	local RedeemedCodes = self:_GetRedeemedCodes(Player)
	if not RedeemedCodes then
		warn(`[CodeService] {Player.Name} attempted redemption before profile load`)
		return false, "Profile not ready."
	end

	if RedeemedCodes[CodeInput] ~= nil then
		return false, "Already Redeemed"
	end

	-- Apply the reward first so a failure mid-apply does NOT consume the code.
	self:_ApplyReward(Player, Definition.Reward)

	RedeemedCodes[CodeInput] = os.time()
	ProfileManager.SyncProfileState(Player)

	return true, "Code Redeemed!"
end

--// Public API

function CodeService:Init()
	Packets.queries.RedeemCode.listen(function(Request, Player: Player?)
		if not Player then
			return { success = false, message = "Player unavailable." }
		end

		local Success, Accepted, Response = xpcall(function()
			return self:_Redeem(Player, Request.code)
		end, debug.traceback)
		if not Success then
			warn(`[CodeService] Redemption failed internally for {Player.Name}: {Accepted}`)
			return { success = false, message = "Code service unavailable." }
		end

		return { success = Accepted == true, message = tostring(Response) }
	end)
end

--// Lifecycle hook (kept for Bootstrap compatibility).
-- Redeemed codes live in the profile, so nothing to flush here.
function CodeService:_OnPlayerRemoving(_Player: Player)
end

return CodeService

