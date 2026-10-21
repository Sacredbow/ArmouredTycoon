--!strict
-- Shot reports spend server-recorded, short-lived hit credits.

const Security = require(script.Parent.Security)

const SHOT_LIFETIME = 6
const MAX_PENDING_SHOTS = 128
const MAX_PELLETS_PER_SHOT = 32
const MAX_SHOTS_PER_MINUTE = 1200
const SHOT_BURST = 2
const MIN_MELEE_INTERVAL = 0.35

type ShotCredit = { ExpiresAt: number, HitsLeft: number }
type WeaponState = {
	Weapon: Tool,
	UpdatedAt: number,
	ShotTokens: number,
	Shots: { ShotCredit },
	LastMeleeAt: number,
}

local StateByPlayer: { [Player]: WeaponState } = setmetatable({}, { __mode = "k" })

local function positiveFinite(value: any, fallback: number): number
	if typeof(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
		return fallback
	end
	return value
end

local function getState(player: Player, weapon: Tool, now: number): WeaponState
	local state = StateByPlayer[player]
	if state and state.Weapon == weapon then
		return state
	end
	local nextState: WeaponState = {
		Weapon = weapon,
		UpdatedAt = now,
		ShotTokens = SHOT_BURST,
		Shots = {},
		LastMeleeAt = if state then state.LastMeleeAt else -math.huge,
	}
	StateByPlayer[player] = nextState
	return nextState
end

local function pruneShots(state: WeaponState, now: number)
	for index = #state.Shots, 1, -1 do
		local shot = state.Shots[index]
		if shot.ExpiresAt <= now or shot.HitsLeft <= 0 then
			table.remove(state.Shots, index)
		end
	end
end

function RecordShot(player: Player, weapon: Tool?): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local settings = Security.SecureSettings(player, weapon)
	if not settings or settings.Type ~= "Gun" then
		return false
	end
	local now = os.clock()
	local state = getState(player, weapon :: Tool, now)
	local rpm = math.min(positiveFinite(settings.ShootRate, 600), MAX_SHOTS_PER_MINUTE)
	local elapsed = math.max(0, now - state.UpdatedAt)
	state.ShotTokens = math.min(SHOT_BURST, state.ShotTokens + elapsed * rpm / 60)
	state.UpdatedAt = now
	if state.ShotTokens < 1 then
		return false
	end
	state.ShotTokens -= 1
	pruneShots(state, now)
	if #state.Shots >= MAX_PENDING_SHOTS then
		table.remove(state.Shots, 1)
	end
	table.insert(state.Shots, {
		ExpiresAt = now + SHOT_LIFETIME,
		HitsLeft = math.clamp(math.floor(positiveFinite(settings.Bullets, 1)), 1, MAX_PELLETS_PER_SHOT),
	})
	return true
end

function ConsumeGunHit(player: Player, weapon: Tool?): boolean
	local state = StateByPlayer[player]
	if not state or state.Weapon ~= weapon then
		return false
	end
	pruneShots(state, os.clock())
	for index, shot in state.Shots do
		if shot.HitsLeft > 0 then
			shot.HitsLeft -= 1
			if shot.HitsLeft == 0 then
				table.remove(state.Shots, index)
			end
			return true
		end
	end
	return false
end

function AllowMeleeHit(player: Player, weapon: Tool?, settings: any): boolean
	if not weapon then
		return false
	end
	local now = os.clock()
	local state = getState(player, weapon, now)
	local rate = math.min(positiveFinite(settings.ShootRate, 120), MAX_SHOTS_PER_MINUTE)
	local interval = math.max(MIN_MELEE_INTERVAL, 60 / rate)
	if now - state.LastMeleeAt < interval then
		return false
	end
	state.LastMeleeAt = now
	return true
end

function Reset(player: Player)
	StateByPlayer[player] = nil
end

return {
	RecordShot = RecordShot,
	ConsumeGunHit = ConsumeGunHit,
	AllowMeleeHit = AllowMeleeHit,
	Reset = Reset,
}
