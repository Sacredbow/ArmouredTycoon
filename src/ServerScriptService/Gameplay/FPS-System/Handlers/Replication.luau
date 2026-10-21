--!strict
--[[
	@class FPSReplication

	Relays cosmetic combat effects after validating the originating player's
	equipped tool and the shape/range of client supplied transient data.
]]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Security = require(script.Parent.Parent.Core.Security)
const ShotAuthority = require(script.Parent.Parent.Core.ShotAuthority)
const NetworkGuard = require(script.Parent.Parent.Parent.Parent.Services.Networking.NetworkGuard)

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const Events = Engine:WaitForChild("Events") :: any

const THROTTLE_RATE = 30
const THROTTLE_WINDOW = 1 / THROTTLE_RATE
const MAX_EFFECT_RANGE = 7000
const MAX_ORIGIN_OFFSET = 32

const REPLICATION_POLICIES = {
	HitEffect = { Rate = 30, Burst = 45 },
	GunStance = { Rate = 20, Burst = 30 },
	ServerBullet = { Rate = 30, Burst = 45 },
	HeadRot = { Rate = 30, Burst = 45 },
	SVLaser = { Rate = 30, Burst = 45 },
	SVFlash = { Rate = 20, Burst = 30 },
	Atirar = { Rate = 30, Burst = 45 },
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

local function secureTracerModifiers(modifiers: any): { [string]: number }?
	if type(modifiers) ~= "table" then
		return nil
	end
	local muzzleVelocity = modifiers.MuzzleVelocity
	local walkMult = modifiers.WalkMult
	if not finiteNumber(muzzleVelocity) then
		muzzleVelocity = 1
	else
		muzzleVelocity = math.clamp(muzzleVelocity, 0.2, 2)
	end
	if not finiteNumber(walkMult) then
		walkMult = 1
	else
		walkMult = math.clamp(walkMult, 0.2, 2)
	end
	return {
		MuzzleVelocity = muzzleVelocity,
		WalkMult = walkMult,
	}
end
local function getServerAnimations(weapon: Tool): any?
	local module = weapon:FindFirstChild("ACS_Animations")
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local success, animations = pcall(require, module)
	if not success or type(animations) ~= "table" then
		return nil
	end
	local required = {
		"SV_RightArmPos", "SV_LeftArmPos", "RightAim", "LeftAim",
		"RightHighReady", "LeftHighReady", "RightLowReady", "LeftLowReady",
		"RightPatrol", "LeftPatrol",
	}
	for _, key in required do
		if not finiteCFrame(animations[key]) then
			return nil
		end
	end
	return animations
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

Players.PlayerRemoving:Connect(function(player)
	LastSentAt[player] = nil
end)

function Bind()
	Events.HitEffect.OnServerEvent:Connect(function(
		player: Player,
		position: Vector3,
		hitPart: Instance,
		normal: Vector3,
		material: Enum.Material,
		_clientSettings: any
	)
		local root = getAliveRoot(player)
		if not NetworkGuard.Allow(player, 'ACSReplication.HitEffect', REPLICATION_POLICIES.HitEffect, nil) then
			return
		end
		local _, settings = getServerSettings(player, nil)
		if not root or not settings or not finiteVector(position) or (position - root.Position).Magnitude > MAX_EFFECT_RANGE then
			return
		end
		if not hitPart or not hitPart:IsDescendantOf(workspace) or not finiteVector(normal) or normal.Magnitude < 0.1 or normal.Magnitude > 1.1 then
			return
		end
		if typeof(material) ~= "EnumItem" or material.EnumType ~= Enum.Material then
			return
		end
		if not CanBroadcast(player, "HitEffect") then
			return
		end
		Events.HitEffect:FireAllClients(player, position, hitPart, normal, material, settings)
	end)

	Events.GunStance.OnServerEvent:Connect(function(player: Player, stance: number, _clientData: any)
		if not NetworkGuard.Allow(player, 'ACSReplication.GunStance', REPLICATION_POLICIES.GunStance, nil) then
			return
		end
		if stance ~= -2 and stance ~= -1 and stance ~= 0 and stance ~= 1 and stance ~= 2 then
			return
		end
		local weapon = getEquippedTool(player, nil)
		local animations = weapon and getServerAnimations(weapon)
		if not getAliveRoot(player) or not weapon or not animations then
			return
		end
		if not CanBroadcast(player, "GunStance") then
			return
		end
		Events.GunStance:FireAllClients(player, stance, animations)
	end)

	Events.ServerBullet.OnServerEvent:Connect(function(
		player: Player,
		origin: Vector3,
		direction: Vector3,
		_requestedWeaponData: any,
		modifierTable: any
	)
		local root = getAliveRoot(player)
		if not NetworkGuard.Allow(player, 'ACSReplication.ServerBullet', REPLICATION_POLICIES.ServerBullet, nil) then
			return
		end
		local weapon, settings = getServerSettings(player, nil)
		local modifiers = secureTracerModifiers(modifierTable)
		if not root or not weapon or not settings or not modifiers or not finiteVector(origin) or not finiteVector(direction) then
			return
		end
		if (origin - root.Position).Magnitude > MAX_ORIGIN_OFFSET or direction.Magnitude < 0.001 or direction.Magnitude > 2 then
			return
		end
		if not CanBroadcast(player, "ServerBullet") then
			return
		end
		local tracerData = {
			Tracer = settings.Tracer == true,
			BulletFlare = settings.BulletFlare == true,
			TracerColor = settings.TracerColor,
			MuzzleVelocity = settings.MuzzleVelocity,
		}
		local tracerModifiers = {
			MuzzleVelocity = modifiers.MuzzleVelocity,
		}
		Events.ServerBullet:FireAllClients(player, origin, direction.Unit, tracerData, tracerModifiers)
	end)

	Events.HeadRot.OnServerEvent:Connect(function(player: Player, cframe: CFrame, aimPitch: number?, aiming: boolean?)
		if not NetworkGuard.Allow(player, 'ACSReplication.HeadRot', REPLICATION_POLICIES.HeadRot, nil) then
			return
		end
		if not getAliveRoot(player) or not finiteCFrame(cframe) or (aimPitch ~= nil and not finiteNumber(aimPitch)) or (aiming ~= nil and typeof(aiming) ~= "boolean") then
			return
		end
		if not CanBroadcast(player, "HeadRot") then
			return
		end
		Events.HeadRot:FireAllClients(player, cframe, if aimPitch then math.clamp(aimPitch, -1.1, 1.1) else nil, aiming)
	end)

	Events.SVLaser.OnServerEvent:Connect(function(
		player: Player,
		position: Vector3?,
		mode: number,
		color: Color3?,
		irMode: boolean?,
		requestedWeapon: Tool
	)
		local weapon = getEquippedTool(player, requestedWeapon)
		if not NetworkGuard.Allow(player, 'ACSReplication.SVLaser', REPLICATION_POLICIES.SVLaser, nil) then
			return
		end
		local root = getAliveRoot(player)
		if not root or not weapon or (mode ~= 1 and mode ~= 2) then
			return
		end
		if mode == 1 and (not position or not color or not finiteVector(position) or not finiteColor(color) or (position - root.Position).Magnitude > MAX_EFFECT_RANGE) then
			return
		end
		if irMode ~= nil and typeof(irMode) ~= "boolean" then
			return
		end
		if not CanBroadcast(player, "SVLaser") then
			return
		end
		Events.SVLaser:FireAllClients(player, position, mode, color, irMode, weapon)
	end)

	Events.SVFlash.OnServerEvent:Connect(function(player: Player, requestedWeapon: Tool, mode: boolean)
		if not NetworkGuard.Allow(player, 'ACSReplication.SVFlash', REPLICATION_POLICIES.SVFlash, nil) then
			return
		end
		local weapon = getEquippedTool(player, requestedWeapon)
		if not getAliveRoot(player) or not weapon or typeof(mode) ~= "boolean" then
			return
		end
		if not CanBroadcast(player, "SVFlash") then
			return
		end
		Events.SVFlash:FireAllClients(player, weapon, mode)
	end)

	Events.Atirar.OnServerEvent:Connect(function(player: Player, weapon: Tool, suppressor: boolean, flashHider: boolean)
		if not NetworkGuard.Allow(player, 'ACSReplication.Atirar', REPLICATION_POLICIES.Atirar, nil) then
			return
		end
		if typeof(suppressor) ~= "boolean" or typeof(flashHider) ~= "boolean" or not ShotAuthority.RecordShot(player, weapon) then
			return
		end
		if not CanBroadcast(player, "Atirar") then
			return
		end
		Events.Atirar:FireAllClients(player, weapon, suppressor, flashHider)
	end)

	Events.Whizz.OnServerEvent:Connect(function(player: Player, victim: Player)
		if not NetworkGuard.Allow(player, 'ACSReplication.Whizz', REPLICATION_POLICIES.Whizz, nil) then
			return
		end
		local sourceRoot = getAliveRoot(player)
		local victimRoot = victim and victim:IsA("Player") and getAliveRoot(victim)
		if not sourceRoot or not victimRoot or victim == player or (sourceRoot.Position - victimRoot.Position).Magnitude > MAX_EFFECT_RANGE then
			return
		end
		if not CanBroadcast(player, "Whizz") then
			return
		end
		Events.Whizz:FireClient(victim)
	end)

	Events.Suppression.OnServerEvent:Connect(function(player: Player, victim: Player, mode: number, intensity: number?, time: number?)
		if not NetworkGuard.Allow(player, 'ACSReplication.Suppression', REPLICATION_POLICIES.Suppression, nil) then
			return
		end
