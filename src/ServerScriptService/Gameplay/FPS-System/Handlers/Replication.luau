--!strict
--[[
	@class FPSReplication

	Relays cosmetic combat effects after validating the originating player's
	equipped tool and the shape/range of client supplied transient data.
]]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Observers = require(ReplicatedStorage.Packages.Observers)

const Security = require(script.Parent.Parent.Core.Security)
const ShotAuthority = require(script.Parent.Parent.Core.ShotAuthority)
const Weapons = require(script.Parent.Parent.Core.Weapons)
const NetworkGuard = require(script.Parent.Parent.Parent.Parent.Services.Networking.NetworkGuard)
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)

const THROTTLE_RATE = 30
const THROTTLE_WINDOW = 1 / THROTTLE_RATE
const MAX_EFFECT_RANGE = 7000
const MAX_ORIGIN_OFFSET = 12

const REPLICATION_POLICIES = {
	HitEffect = { Rate = 30, Burst = 45 },
	GunStance = { Rate = 20, Burst = 30 },
	ProjectileIntent = { Rate = 30, Burst = 45 },
	SVLaser = { Rate = 15, Burst = 20 },
	SVFlash = { Rate = 20, Burst = 30 },
	WeaponFireIntent = { Rate = 30, Burst = 45 },
	Whizz = { Rate = 10, Burst = 20 },
	Suppression = { Rate = 10, Burst = 20 },
}

type ThrottleKey = { [string]: number }
local LastSentAt: { [Player]: ThrottleKey } = setmetatable({}, { __mode = "k" })

local function finiteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function finiteVector(value: any): boolean
	return typeof(value) == "Vector3"
		and finiteNumber(value.X)
		and finiteNumber(value.Y)
		and finiteNumber(value.Z)
end

local function finiteCFrame(value: any): boolean
	return typeof(value) == "CFrame" and finiteVector(value.Position) and finiteVector(value.LookVector)
end

local function finiteColor(value: any): boolean
	return typeof(value) == "Color3"
		and finiteNumber(value.R)
		and finiteNumber(value.G)
		and finiteNumber(value.B)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function getAliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return getRoot(player)
end

local function sendNearby(packet: any, center: Vector3, payload: any)
	for _, recipient in Players:GetPlayers() do
		local recipientRoot = getRoot(recipient)
		if recipientRoot and (recipientRoot.Position - center).Magnitude <= MAX_EFFECT_RANGE then
			packet.sendTo(payload, recipient)
		end
	end
end
local function getEquippedTool(player: Player, requested: Tool?): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	if requested and requested:IsA("Tool") and requested.Parent == character then
		return requested
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			return child
		end
	end
	return nil
end

local function getServerSettings(player: Player, requested: Tool?): (Tool?, any?)
	local weapon = getEquippedTool(player, requested)
	if not weapon then
		return nil, nil
	end
	return weapon, Security.SecureSettings(player, weapon)
end

local function CanBroadcast(player: Player, category: string): boolean
	local now = os.clock()
	local playerThrottle = LastSentAt[player]
	if not playerThrottle then
		playerThrottle = {}
		LastSentAt[player] = playerThrottle
	end
	local last = playerThrottle[category] or 0
	if now - last < THROTTLE_WINDOW then
		return false
	end
	playerThrottle[category] = now
	return true
end

Observers.observePlayer(function(player: Player)
	return function()
		LastSentAt[player] = nil
	end
end)

function Bind()
	NetworkGuard.Listen(Packets.packets.HitEffectIntent, "ACSReplication.HitEffectIntent", REPLICATION_POLICIES.HitEffect, function(data, player)
		local root = getAliveRoot(player)
		local weapon, settings = getServerSettings(player, nil)
		local material = if typeof(data.material) == "string" then Enum.Material[data.material] else nil
		if not root or not settings or not material or not finiteVector(data.position) or (data.position - root.Position).Magnitude > MAX_EFFECT_RANGE then
			return
		end
		if not data.hitPart or not data.hitPart:IsDescendantOf(workspace) or not finiteVector(data.normal) or data.normal.Magnitude < 0.1 or data.normal.Magnitude > 1.1 then
			return
		end
		if not CanBroadcast(player, "HitEffect") then
			return
		end
		sendNearby(Packets.packets.HitEffectPresentation, data.position, {
			shooterUserId = player.UserId,
			weapon = weapon,
			position = data.position,
			hitPart = data.hitPart,
			normal = data.normal,
			material = data.material,
		})
	end)

	NetworkGuard.Listen(Packets.packets.GunStanceIntent, "ACSReplication.GunStanceIntent", REPLICATION_POLICIES.GunStance, function(data, player)
		if data.stance ~= -2 and data.stance ~= -1 and data.stance ~= 0 and data.stance ~= 1 and data.stance ~= 2 then
			return
		end
		local root = getAliveRoot(player)
		local weapon = getEquippedTool(player, nil)
		if not root or not weapon then
			return
		end
		if not CanBroadcast(player, "GunStance") then
			return
		end
		sendNearby(Packets.packets.GunStancePresentation, root.Position, {
			shooterUserId = player.UserId,
			stance = data.stance,
		})
	end)

	NetworkGuard.Listen(Packets.packets.ProjectileIntent, "ACSReplication.ProjectileIntent", REPLICATION_POLICIES.ProjectileIntent, function(data, player)
		local root = getAliveRoot(player)
		local weapon, settings = getServerSettings(player, nil)
		local muzzleVelocity = data.muzzleVelocity
		if not root or not weapon or not settings or not finiteVector(data.origin) or not finiteVector(data.direction) or not finiteNumber(muzzleVelocity) then
			return
		end
		if (data.origin - root.Position).Magnitude > MAX_ORIGIN_OFFSET or data.direction.Magnitude < 0.001 or data.direction.Magnitude > 2 then
			return
		end
		if not CanBroadcast(player, "ProjectileIntent") then
			return
		end

		local safeVelocity = math.clamp(muzzleVelocity, 0.2, 2)
		sendNearby(Packets.packets.ProjectilePresentation, data.origin, {
			shooterUserId = player.UserId,
			origin = data.origin,
			direction = data.direction.Unit,
			tracer = settings.Tracer == true,
			bulletFlare = settings.BulletFlare == true,
			tracerColor = if finiteColor(settings.TracerColor) then settings.TracerColor else Color3.new(1, 1, 1),
			muzzleVelocity = safeVelocity,
		})
	end)

	NetworkGuard.Listen(Packets.packets.LaserIntent, "ACSReplication.LaserIntent", REPLICATION_POLICIES.SVLaser, function(data, player)
		local root = getAliveRoot(player)
		local weapon = getEquippedTool(player, data.weapon)
		if not root or not weapon or (data.mode ~= 1 and data.mode ~= 2) then
			return
		end
		if data.mode == 1 and (not data.position or not data.color or not finiteVector(data.position) or not finiteColor(data.color) or (data.position - root.Position).Magnitude > MAX_EFFECT_RANGE) then
			return
		end
		if typeof(data.infrared) ~= "boolean" then
			return
		end
		if not CanBroadcast(player, "SVLaser") then
			return
		end
		sendNearby(Packets.packets.LaserPresentation, data.position or root.Position, {
			shooterUserId = player.UserId,
			weapon = weapon,
			position = data.position,
			mode = data.mode,
			color = data.color,
			infrared = data.infrared,
		})
	end)

	NetworkGuard.Listen(Packets.packets.FlashIntent, "ACSReplication.FlashIntent", REPLICATION_POLICIES.SVFlash, function(data, player)
		local root = getAliveRoot(player)
		local weapon = getEquippedTool(player, data.weapon)
		if not root or not weapon or typeof(data.enabled) ~= "boolean" then
			return
		end
		if not CanBroadcast(player, "SVFlash") then
			return
		end
		sendNearby(Packets.packets.FlashPresentation, root.Position, {
			shooterUserId = player.UserId,
			weapon = weapon,
			enabled = data.enabled,
		})
	end)

	NetworkGuard.Listen(Packets.packets.WeaponFireIntent, "ACSReplication.WeaponFireIntent", REPLICATION_POLICIES.WeaponFireIntent, function(data, player)
		local root = getAliveRoot(player)
		local weapon = getEquippedTool(player, data.weapon)
		local combatState = Weapons.GetCombatState(player, weapon)
		if not root or not weapon or not combatState or not ShotAuthority.RecordShot(player, weapon) then
			return
		end
		if not CanBroadcast(player, "WeaponFireIntent") then
			return
		end
		sendNearby(Packets.packets.WeaponFirePresentation, root.Position, {
			shooterUserId = player.UserId,
			weapon = weapon,
			suppressor = combatState.suppressor == true,
			flashHider = combatState.flashHider == true,
		})
	end)
	NetworkGuard.Listen(Packets.packets.WhizzIntent, "ACSReplication.WhizzIntent", REPLICATION_POLICIES.Whizz, function(data, player)
		local victim = data.victim
		local sourceRoot = getAliveRoot(player)
		local victimRoot = if victim and victim:IsA("Player") then getAliveRoot(victim) else nil
		if not sourceRoot or not victimRoot or victim == player or (sourceRoot.Position - victimRoot.Position).Magnitude > MAX_EFFECT_RANGE then
			return
		end
		if not CanBroadcast(player, "Whizz") then
			return
		end
		Packets.packets.WhizzPresentation.sendTo({
			shooterUserId = player.UserId,
		}, victim)
	end)

	NetworkGuard.Listen(Packets.packets.SuppressionIntent, "ACSReplication.SuppressionIntent", REPLICATION_POLICIES.Suppression, function(data, player)
		local victim = data.victim
		local sourceRoot = getAliveRoot(player)
		local victimRoot = if victim and victim:IsA("Player") then getAliveRoot(victim) else nil
		if not sourceRoot or not victimRoot or victim == player or (sourceRoot.Position - victimRoot.Position).Magnitude > MAX_EFFECT_RANGE or data.mode ~= 1 or (data.intensity ~= nil and not finiteNumber(data.intensity)) or (data.time ~= nil and not finiteNumber(data.time)) then
			return
		end
		if not CanBroadcast(player, "Suppression") then
			return
		end

		Packets.packets.SuppressionPresentation.sendTo({
			mode = data.mode,
			intensity = math.clamp(data.intensity or 1, 0, 1),
			duration = math.clamp(data.time or 1, 0.05, 5),
		}, victim)
	end)
end

return {
	Bind = Bind,
}