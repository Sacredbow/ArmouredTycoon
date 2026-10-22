--!strict
--[[
	@class FPSCombat

	@desc
	Wires gameplay-authoritative remotes for the ACS engine: damage,
	grenades, stance, and surrender. Each handler validates the request
	before delegating to Core modules (Damage / Weapons / Security) or
	PlayerRuntimeState.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const Damage = require(script.Parent.Parent.Core.Damage)
const Weapons = require(script.Parent.Parent.Core.Weapons)
const Security = require(script.Parent.Parent.Core.Security)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
const NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const Events = Engine:WaitForChild("Events") :: any

--// Constants

-- Maximum distance from the thrower's character at which a grenade may be
-- spawned. Prevents cheaters from forging spawnCFrame to place grenades
-- directly on distant players.
const MAX_GRENADE_THROW_DISTANCE = 300

const SHIELD_HIT_POLICY = { Rate = 25, Burst = 40 }
const DAMAGE_POLICY = { Rate = 25, Burst = 40 }
const GRENADE_POLICY = { Rate = 2, Burst = 4 }
const STANCE_POLICY = { Rate = 20, Burst = 30 }
const SURRENDER_POLICY = { Rate = 8, Burst = 12 }
const MAX_SURRENDER_DISTANCE = 12

--// Public API

function Bind()
	Events.ShieldHit.OnServerEvent:Connect(function(player: Player, shieldModel: Model)
		if NetworkGuard.Allow(player, "ACSShieldHit", SHIELD_HIT_POLICY, shieldModel) then
			Damage.HandleShieldHit(player, shieldModel)
		end
	end)

	Events.Damage.OnServerInvoke = function(
		player: Player,
		weapon: Tool?,
		targetHumanoid: Humanoid?,
		hitType: number,
		modifiers: any
	)
		if not NetworkGuard.Allow(player, "ACSDamage", DAMAGE_POLICY, nil) then
			return
		end
		Damage.HandleDamageRequest(
			player,
			weapon,
			targetHumanoid,
			hitType,
			modifiers
		)
	end

	Events.Grenade.OnServerEvent:Connect(function(
		player: Player,
		grenadeTool: Tool?,
		weaponSettings: any,
		spawnCFrame: CFrame,
		impulseDirection: Vector3,
		impulsePower: number
	)
		if not NetworkGuard.Allow(player, "ACSGrenade", GRENADE_POLICY, nil) then
			return
		end
		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		-- Validate payload types before touching physics / settings tables.
		if typeof(spawnCFrame) ~= "CFrame" or typeof(impulseDirection) ~= "Vector3" then
			warn(`[FPS.Combat] {player.Name} sent invalid grenade payload types`)
			return
		end
		if typeof(impulsePower) ~= "number" or impulsePower ~= impulsePower or math.abs(impulsePower) > 1e6 then
			warn(`[FPS.Combat] {player.Name} sent non-finite grenade impulse`)
			return
		end

		if not grenadeTool or not weaponSettings then
			Security.RejectRequest(player, "grenade event with missing tool or settings")
			return
		end

		local serverSettings = Security.SecureSettings(player, grenadeTool, weaponSettings)
		if not serverSettings or serverSettings.Type ~= "Grenade" then
			return
		end

		-- Reject grenades spawned unreasonably far from the thrower; the
		-- client could otherwise forge spawnCFrame to teleport explosives.
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			local throwDistance = (spawnCFrame.Position - rootPart.Position).Magnitude
			if throwDistance > MAX_GRENADE_THROW_DISTANCE then
				warn(`[FPS.Combat] {player.Name} attempted a grenade spawn {math.floor(throwDistance)} studs away`)
				return
			end
		end

		Weapons.SpawnGrenade(player, grenadeTool, serverSettings, spawnCFrame, impulseDirection, impulsePower)
	end)

	Events.Stance.OnServerEvent:Connect(function(player: Player, stance: number, lean: number)
		if not NetworkGuard.Allow(player, "ACSStance", STANCE_POLICY, nil) then
			return
		end
		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		-- Stance/lean feed the ByteNet int32 packet; garbage types would
		-- corrupt the broadcast to every client.
		if typeof(stance) ~= "number" or typeof(lean) ~= "number" or stance ~= math.floor(stance) or stance < 0 or stance > 2 or lean ~= lean or lean == math.huge or lean == -math.huge or lean < -1 or lean > 1 then
			warn(`[FPS.Combat] {player.Name} sent invalid stance payload`)
			return
		end

		if not character:FindFirstChild("ACS_Client") then
			return
		end

		local torso = character:FindFirstChild("Torso")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not torso or not rootPart then
			return
		end

		local rootJoint = rootPart:FindFirstChild("RootJoint")
		local rightShoulder = torso:FindFirstChild("Right Shoulder")
		local leftShoulder = torso:FindFirstChild("Left Shoulder")
		local rightHip = torso:FindFirstChild("Right Hip")
		local leftHip = torso:FindFirstChild("Left Hip")

		if not rootJoint or not rightShoulder or not leftShoulder or not rightHip or not leftHip then
			return
		end

		Weapons.SetStanceState(player, character, stance, lean)
	end)

	Events.Surrender.OnServerEvent:Connect(function(player: Player, victim: Player?)
		if not NetworkGuard.Allow(player, "ACSSurrender", SURRENDER_POLICY, nil) then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			return
		end

		if victim then
			if victim == player or not victim.Character then
				return
			end

			local victimHumanoid = victim.Character:FindFirstChildOfClass("Humanoid")
			local sourceRoot = character:FindFirstChild("HumanoidRootPart")
			local victimRoot = victim.Character:FindFirstChild("HumanoidRootPart")
			if not victimHumanoid or victimHumanoid.Health <= 0 or not sourceRoot or not sourceRoot:IsA("BasePart") or not victimRoot or not victimRoot:IsA("BasePart") then
				return
			end
			if (sourceRoot.Position - victimRoot.Position).Magnitude > MAX_SURRENDER_DISTANCE then
				return
			end

			if not victim.Character:FindFirstChild("ACS_Client") then
				return
			end

			if PlayerRuntimeState.IsSurrendering(victim) then
				PlayerRuntimeState.SetSurrendering(victim, false)
			end
		end

		if not character:FindFirstChild("ACS_Client") then
			return
		end

		if not PlayerRuntimeState.IsSurrendering(player) then
			PlayerRuntimeState.SetSurrendering(player, true)
		end
	end)
end

return {
	Bind = Bind,
}

