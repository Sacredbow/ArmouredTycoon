--!strict
--[[
	@class FPSDamage

	@desc
	Server-authoritative damage validation, calculation, and queueing for
	the ACS combat engine. Replaces the legacy inline damage logic that was
	buried in FPSSystem.server.luau (SKP_0-style identifiers, duplicated
	validation, direct ACS_Client indexing).

	Responsibilities:
	- Payload sanity checks (finite numbers, typed tables) before any logic
	- Authorization token + weapon-settings validation via FPSSecurity
	- Head / torso / limb damage with distance falloff
	- Armour penetration (helmet / vest) read defensively from ACS_Client
	- Team rules (no team-kill, or scaled team damage from GameRules)
	- ECS DamageRequest queueing consumed by ECS.Systems.Combat.DamageSystem
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Types = require(script.Parent.Types)
const Security = require(script.Parent.Security)
const State = require(script.Parent.State)

--// Micro-Optimisations

const math_max = math.max
const math_min = math.min
const math_floor = math.floor
const math_clamp = math.clamp
const math_random = math.random

--// Constants

const FALLOFF_DIVISOR = 25
const MIN_ARMOUR_DAMAGE = 0.5
const SELF_DAMAGE_MAX = 500
const HEAD_HIT_TYPE = 1
const TORSO_HIT_TYPE = 2
const SHIELD_BASE_HEALTH = 750

--// Internal Utilities

local function rollDamageRange(range: { number }?): number
	if type(range) ~= "table" then
		return 0
	end

	local firstValue = tonumber(range[1]) or 0
	local secondValue = tonumber(range[2]) or firstValue
	local low = math_floor(math_min(firstValue, secondValue))
	local high = math_floor(math_max(firstValue, secondValue))

	if high <= low then
		return low
	end

	return math_random(low, high)
end

-- Requests are consumed each tick by ECS Systems/Combat/DamageSystem.
local function queueDamage(attacker: Player?, targetHumanoid: Humanoid, amount: number)
	if amount <= 0 then
		return
	end

	ECS.createEntity({
		Name = "DamageRequest",
		DamageRequest = {
			attacker = attacker,
			humanoid = targetHumanoid,
			amount = amount,
		},
	})
end



--// Shield detection
--(Player = 750, Base value)

local ShieldUsers: {[Player]: number} = {}

-- Clean up shield state when a player leaves to avoid a memory leak.
Players.PlayerRemoving:Connect(function(player: Player)
	ShieldUsers[player] = nil
end)

local function ValidateShieldHealth(Player: Player, ShieldModel: Model)
	-- The player is allowed to keep the shield only while its health is above 0.
	if ShieldUsers[Player] and ShieldUsers[Player] <= 0 then
		ShieldUsers[Player] = nil
		ShieldModel:Destroy()
	end
end

local function ShieldDamage(Player: Player, ShieldModel: Model, Damage: number)
	-- Register the player if not already in the table.
	if not ShieldUsers[Player] then
		ShieldUsers[Player] = SHIELD_BASE_HEALTH
	end

	-- Clamp so the shield never goes negative.
	ShieldUsers[Player] = math_max(0, ShieldUsers[Player] - Damage)

	ValidateShieldHealth(Player, ShieldModel)

	-- Update the shield's on-model counter (defensively, in case parts are missing).
	local Counter = ShieldModel:FindFirstChild("Counter")
	if Counter then
		local CounterGUI = Counter:FindFirstChild("SurfaceGui")
		local CounterText = CounterGUI and CounterGUI:FindFirstChild("TextLabel") :: TextLabel
		if CounterText then
			CounterText.Text = tostring(ShieldUsers[Player] or 0)
		end
	end
end

-- Server entry point for shield hits. Validates that the shield actually
-- belongs to the target player's character before applying damage.
function HandleShieldHit(Player: Player, ShieldModel: Model, Damage: number)
	if typeof(Damage) ~= "number" or Damage ~= Damage or Damage <= 0 then
		return
	end

	-- Only allow damaging a shield that is currently equipped by the player.
	local character = Player.Character
	if not character or ShieldModel.Parent ~= character then
		return
	end

	ShieldDamage(Player, ShieldModel, Damage)
end
--// Armour

local function getNumberValue(parent: Instance?, name: string): NumberValue?
	local child = parent and parent:FindFirstChild(name)
	if child and child:IsA("NumberValue") then
		return child
	end

	return nil
end


local function applyArmour(
	targetCharacter: Model,
	hitType: number,
	weaponSettings: Types.WeaponSettings,
	damage: number
): number
	if weaponSettings.IgnoreProtection then
		return damage
	end

	local bulletPenetration = weaponSettings.BulletPenetration or 0
	if bulletPenetration <= 0 then
		return damage
	end

	-- ACS_Client / Protecao are optional on some rigs; never index directly.
	local acsClient = targetCharacter:FindFirstChild("ACS_Client")
	if not acsClient then
		return damage
	end

	local protection = acsClient:FindFirstChild("Protecao")
	if not protection then
		return damage
	end

	-- Head shots are stopped by the helmet; torso/limb hits by the vest.
	local protectionValue: NumberValue?
	if hitType == HEAD_HIT_TYPE then
		protectionValue = getNumberValue(protection, "HelmetProtect")
	else
		protectionValue = getNumberValue(protection, "VestProtect")
	end

	if protectionValue and protectionValue.Value > 0 and bulletPenetration < protectionValue.Value then
		local reduction = bulletPenetration / protectionValue.Value
		return math_max(MIN_ARMOUR_DAMAGE, damage * reduction)
	end

	return damage
end

--// Damage Calculation

function CalculateDamage(
	attacker: Player,
	targetHumanoid: Humanoid,
	distance: number,
	hitType: number,
	weaponSettings: Types.WeaponSettings,
	modifiers: Types.ModifierSettings
)
	local parentModel = targetHumanoid.Parent
	if not parentModel or not parentModel:IsA("Model") then
		return
	end

	local targetPlayer = Players:GetPlayerFromCharacter(parentModel)
	local gameRules = State.GameRules

	local minDamage = (weaponSettings.MinDamage or 0) * (modifiers.minDamageMod or 1)
	local damageModifier = modifiers.DamageMod or 1
	local damageFalloff = weaponSettings.DamageFallOf or 0
	local damageDistance = math_max(distance, 0)

	local baseDamage: number
	if hitType == HEAD_HIT_TYPE then
		baseDamage = rollDamageRange(weaponSettings.HeadDamage)
	elseif hitType == TORSO_HIT_TYPE then
		baseDamage = rollDamageRange(weaponSettings.TorsoDamage)
	else
		baseDamage = rollDamageRange(weaponSettings.LimbDamage)
	end

	local damage = math_max(minDamage, (baseDamage * damageModifier) - (damageDistance / FALLOFF_DIVISOR) * damageFalloff)
	damage = applyArmour(parentModel, hitType, weaponSettings, damage)

	if targetPlayer then
		if targetPlayer.Team ~= attacker.Team or targetPlayer.Neutral then
			queueDamage(attacker, targetHumanoid, damage)
			return
		end

		if not (gameRules and gameRules.TeamKill) then
			return
		end

		queueDamage(attacker, targetHumanoid, damage * (gameRules.TeamDmgMult or 1))
		return
	end

	-- No player character => NPC / neutral target; apply full damage.
	queueDamage(attacker, targetHumanoid, damage)
end

--// Public API — Remote Entry Point

function HandleDamageRequest(
	player: Player,
	weapon: Tool?,
	targetHumanoid: Humanoid?,
	distance: number,
	hitType: number,
	weaponSettings: any,
	modifiers: any,
	isSelfDamage: boolean,
	selfDamageAmount: number,
	authToken: string
)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Reject non-finite / mis-typed payloads before reaching gameplay logic.
	if typeof(distance) ~= "number" or distance ~= distance or math.abs(distance) == math.huge then
		warn(`[FPS.Damage] {player.Name} sent non-finite distance`)
		return
	end
	if typeof(hitType) ~= "number" or type(weaponSettings) ~= "table" or type(modifiers) ~= "table" then
		warn(`[FPS.Damage] {player.Name} sent invalid damage payload types`)
		return
	end

	if not Security.IsAuthorized(player, authToken) then
		Security.BanPlayer(player, "damage request with incorrect authorization token")
		return
	end

	if isSelfDamage then
		if typeof(selfDamageAmount) ~= "number" or selfDamageAmount ~= selfDamageAmount then
			warn(`[FPS.Damage] {player.Name} sent invalid self damage amount`)
			return
		end

		-- Self-inflicted damage must not register the shooter as their own
		-- killer; otherwise repeated self-damage + death farms cash/kill credit.
		queueDamage(nil, humanoid, math_clamp(selfDamageAmount, 0, SELF_DAMAGE_MAX))
		return
	end

	if not weapon then
		Security.BanPlayer(player, "damage request without a weapon")
		return
	end

	local settingsValid = Security.SecureSettings(player, weapon, weaponSettings)
	if not settingsValid or not targetHumanoid then
		return
	end

	CalculateDamage(
		player,
		targetHumanoid,
		distance,
		hitType,
		weaponSettings :: Types.WeaponSettings,
		modifiers :: Types.ModifierSettings
	)
end

return {
	HandleDamageRequest = HandleDamageRequest,
	HandleShieldHit = HandleShieldHit,
	CalculateDamage = CalculateDamage,
	QueueDamage = queueDamage,
	RollDamageRange = rollDamageRange,
}

