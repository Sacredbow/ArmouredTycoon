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
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const ServerScriptService = game:GetService("ServerScriptService")
const DataStoreService = game:GetService("DataStoreService")
const RunService = game:GetService("RunService")

--// Modules

const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const Codes = require(script.Codes)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)


local function FindPlayerEntity(Player: Player): number?
	for Entity, PlayerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if PlayerRef == Player then return Entity end
	end
	return nil
end

-- A new campaign key starts when this release first runs on a live server.
-- Keep this key stable across hotfixes so restarts cannot extend expiry.
local CAMPAIGN_KEY = "R3L3ASE_FR33MULTI_STARTER_v1"
local CampaignStore = DataStoreService:GetDataStore("PromoCampaigns")
--// Module

local CodeService: { [string]: any } = {}


--// Constructor

--// Internal Methods

-- Returns the player's redeemed codes map (code -> unix timestamp).
-- Returns nil when the profile isn't loaded yet (redeem should be deferred).
-- Self-heals a corrupt non-table RedeemedCodes field instead of erroring.
function CodeService._GetRedeemedCodes(Player: Player): { [string]: number }?
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
function CodeService._ApplyReward(Player: Player, Reward: any)
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
		local Entity = FindPlayerEntity(Player)
		if Entity then
			local Current = ECS.world:get(Entity, ECS.Components.PlayerMultiplier) or 1
			ECS.world:set(Entity, ECS.Components.PlayerMultiplier, math.max(Current, Multiplier))
		end
	end
end

function CodeService._Redeem(Player: Player, CodeInput: string): (boolean, string)
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

	if not Codes.IsCampaignReady() then
		return false, "Code service unavailable."
	end

	if Codes.IsExpired(CodeInput) then
		return false, "Code Expired"
	end

	local RedeemedCodes = CodeService._GetRedeemedCodes(Player)
	if not RedeemedCodes then
		warn(`[CodeService] {Player.Name} attempted redemption before profile load`)
		return false, "Profile not ready."
	end

	if RedeemedCodes[CodeInput] ~= nil then
		return false, "Already Redeemed"
	end

	-- Apply the reward first so a failure mid-apply does NOT consume the code.
	CodeService._ApplyReward(Player, Definition.Reward)

	RedeemedCodes[CodeInput] = os.time()
	ProfileManager.SyncProfileState(Player)

	return true, "Code Redeemed!"
end

--// Public API

function CodeService.Init()
	task.spawn(function()
		if RunService:IsStudio() then
			Codes.SetCampaignStartUnix(os.time())
			return
		end
		local success, startUnix = pcall(function()
			return CampaignStore:UpdateAsync(CAMPAIGN_KEY, function(existing)
				if type(existing) == "number" and existing > 0 then
					return existing
				end
				return os.time()
			end)
		end)
		if not success then
			warn(`[CodeService] Could not load campaign start: {startUnix}`)
			return
		end
		if type(startUnix) == "number" and startUnix > 0 then
			Codes.SetCampaignStartUnix(startUnix)
		end
	end)

	NetworkGuard.Query(Packets.queries.RedeemCode, "RedeemCode", {
	Rate = 2,
	Burst = 3,
	Validate = function(request)
		return type(request) == "table" and type(request.code) == "string" and #request.code >= 1 and #request.code <= 64
	end,
}, function(Request, Player: Player?)
		if not Player then
			return { success = false, message = "Player unavailable." }
		end

		local Success, Accepted, Response = xpcall(function()
			return CodeService._Redeem(Player, Request.code)
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
function CodeService._OnPlayerRemoving(_Player: Player)
end

return CodeService

