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
	- Equipped weapon and server settings validation via FPSSecurity
	- Head / torso / limb damage with distance falloff
	- Armour penetration (helmet / vest) read defensively from ACS_Client
	- Team rules (no team-kill, or scaled team damage from GameRules)
	- ECS DamageRequest queueing consumed by ECS.Systems.Combat.DamageSystem
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Workspace = game:GetService("Workspace")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Types = require(script.Parent.Types)
const Security = require(script.Parent.Security)
const ShotAuthority = require(script.Parent.ShotAuthority)
const State = require(script.Parent.State)

--// Micro-Optimisations

const math_max = math.max
const math_min = math.min
const math_floor = math.floor
const math_random = math.random

--// Constants

const FALLOFF_DIVISOR = 25
const MIN_ARMOUR_DAMAGE = 0.5
const HEAD_HIT_TYPE = 1
const TORSO_HIT_TYPE = 2
const SHIELD_BASE_HEALTH = 750
const MAX_DAMAGE_DISTANCE = 7000
const MELEE_DISTANCE_BUFFER = 6

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
-- Each equipped shield owns its own health; weak keys release destroyed models.
local ShieldHealthByModel: { [Model]: number } = setmetatable({}, { __mode = "k" })

local function ShieldDamage(shieldModel: Model, damage: number)
	local health = math_max(0, (ShieldHealthByModel[shieldModel] or SHIELD_BASE_HEALTH) - damage)
	if health <= 0 then
		ShieldHealthByModel[shieldModel] = nil
		shieldModel:Destroy()
		return
	end
	ShieldHealthByModel[shieldModel] = health

	local counter = shieldModel:FindFirstChild("Counter")
	local counterGui = counter and counter:FindFirstChild("SurfaceGui")
	local counterText = counterGui and counterGui:FindFirstChild("TextLabel")
	if counterText and counterText:IsA("TextLabel") then
		counterText.Text = tostring(health)
	end
end

-- Damage comes from the server's equipped weapon settings, never client data.
function HandleShieldHit(player: Player, shieldModel: Model)
	if typeof(shieldModel) ~= "Instance" or not shieldModel:IsA("Model") or shieldModel.Name ~= "Shield" then
		return
	end
	local targetCharacter = shieldModel.Parent
	if not targetCharacter or not targetCharacter:IsA("Model") or not Players:GetPlayerFromCharacter(targetCharacter) then
		return
	end
	local character = player.Character
	if not character or character == targetCharacter then
		return
	end
	local weapon = character:FindFirstChildOfClass("Tool")
	local settingsModule = weapon and weapon:FindFirstChild("ACS_Settings")
	if not settingsModule or not settingsModule:IsA("ModuleScript") then
		return
	end
	local success, settings = pcall(require, settingsModule)
	if not success or type(settings) ~= "table" or type(settings.LimbDamage) ~= "table" then
		return
	end
	local damage = settings.LimbDamage[1]
	if type(damage) ~= "number" or damage ~= damage or damage <= 0 then
		return
	end
	local attackerRoot = character:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not attackerRoot:IsA("BasePart") or not targetRoot or not targetRoot:IsA("BasePart") then
		return
	end
	local distance = (targetRoot.Position - attackerRoot.Position).Magnitude
	if distance > MAX_DAMAGE_DISTANCE then
		return
	end
	if settings.Type == "Melee" then
		local bladeRange = settings.BladeRange
		if typeof(bladeRange) ~= "number" or distance > bladeRange + MELEE_DISTANCE_BUFFER
			or not ShotAuthority.AllowMeleeHit(player, weapon, settings) then
			return
		end
	elseif settings.Type ~= "Gun" or not ShotAuthority.ConsumeGunHit(player, weapon) then
		return
	end
	ShieldDamage(shieldModel, math_min(damage, 200))
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

local function HasLineOfSight(attackerCharacter: Model, targetCharacter: Model, origin: Vector3, targetPosition: Vector3): boolean
	local direction = targetPosition - origin
	if direction.Magnitude <= 0.01 then
		return true
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { attackerCharacter }
	local result = Workspace:Raycast(origin, direction, raycastParams)
	if not result then
		return true
	end
	return result.Instance:IsDescendantOf(targetCharacter)
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
	hitType: number,
	modifiers: any
)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Reject mis-typed payloads before reaching gameplay logic.
	if hitType ~= HEAD_HIT_TYPE and hitType ~= TORSO_HIT_TYPE and hitType ~= 3 then
		return
	end
	if type(modifiers) ~= "table" then
		warn(`[FPS.Damage] {player.Name} sent invalid damage payload types`)
		return
	end

	local serverSettings = Security.SecureSettings(player, weapon)
	if not serverSettings then
		return
	end

	if typeof(targetHumanoid) ~= "Instance" or not targetHumanoid:IsA("Humanoid")
		or targetHumanoid == humanoid or targetHumanoid.Health <= 0
		or not targetHumanoid:IsDescendantOf(workspace) then
		return
	end

	local attackerRoot = character:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetHumanoid.RootPart
	if not attackerRoot or not attackerRoot:IsA("BasePart") or not targetRoot then
		return
	end
	local distance = (targetRoot.Position - attackerRoot.Position).Magnitude
	if distance > MAX_DAMAGE_DISTANCE then
		return
	end
	local targetCharacter = targetHumanoid.Parent
	if not targetCharacter or not targetCharacter:IsA("Model") then
		return
	end
	local targetPart = if hitType == HEAD_HIT_TYPE then targetCharacter:FindFirstChild("Head") else if hitType == TORSO_HIT_TYPE then targetCharacter:FindFirstChild("UpperTorso") or targetRoot else targetRoot
	if not targetPart or not targetPart:IsA("BasePart") or not HasLineOfSight(character, targetCharacter, attackerRoot.Position, targetPart.Position) then
		return
	end
	if serverSettings.Type == "Melee" then
		local bladeRange = serverSettings.BladeRange
		if typeof(bladeRange) ~= "number" or distance > bladeRange + MELEE_DISTANCE_BUFFER then
			return
		end
	end
	local secureModifiers = Security.SecureModifiers(player, modifiers)
	if not secureModifiers then
		return
	end

	if serverSettings.Type == "Gun" then
		if not ShotAuthority.ConsumeGunHit(player, weapon) then
			return
		end
	elseif serverSettings.Type == "Melee" then
		if not ShotAuthority.AllowMeleeHit(player, weapon, serverSettings) then
			return
		end
	else
		return
	end

	CalculateDamage(
		player,
		targetHumanoid,
		distance,
		hitType,
		serverSettings :: Types.WeaponSettings,
		secureModifiers :: Types.ModifierSettings
	)
end

return {
	HandleDamageRequest = HandleDamageRequest,
	HandleShieldHit = HandleShieldHit,
	CalculateDamage = CalculateDamage,
	QueueDamage = queueDamage,
	RollDamageRange = rollDamageRange,
}

