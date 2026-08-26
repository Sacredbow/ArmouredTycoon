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

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const Events = Engine:WaitForChild("Events") :: any

--// Constants

-- Maximum distance from the thrower's character at which a grenade may be
-- spawned. Prevents cheaters from forging spawnCFrame to place grenades
-- directly on distant players.
const MAX_GRENADE_THROW_DISTANCE = 300

--// Public API

function Bind()
	Events.ShieldHit.OnServerEvent:Connect(function(player: Player, shieldModel: Model?, damage: number)
		Damage.HandleShieldHit(player, shieldModel, damage)
	end)

	Events.Damage.OnServerInvoke = function(
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
		Damage.HandleDamageRequest(
			player,
			weapon,
			targetHumanoid,
			distance,
			hitType,
			weaponSettings,
			modifiers,
			isSelfDamage,
			selfDamageAmount,
			authToken
		)
	end

	Events.Grenade.OnServerEvent:Connect(function(
		player: Player,
		grenadeTool: Tool?,
		weaponSettings: any,
		spawnCFrame: CFrame,
		impulseDirection: Vector3,
		impulsePower: number,
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

		-- Validate payload types before touching physics / settings tables.
		if typeof(spawnCFrame) ~= "CFrame" or typeof(impulseDirection) ~= "Vector3" then
			warn(`[FPS.Combat] {player.Name} sent invalid grenade payload types`)
			return
		end
		if typeof(impulsePower) ~= "number" or impulsePower ~= impulsePower or math.abs(impulsePower) > 1e6 then
			warn(`[FPS.Combat] {player.Name} sent non-finite grenade impulse`)
			return
		end

		if not Security.IsAuthorized(player, authToken) then
			Security.BanPlayer(player, "grenade event with wrong permission code")
			return
		end

		if not grenadeTool or not weaponSettings then
			Security.BanPlayer(player, "grenade event with missing tool or settings")
			return
		end

		local isValidWeapon = Security.SecureSettings(player, grenadeTool, weaponSettings)
		if not isValidWeapon or weaponSettings.Type ~= "Grenade" then
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

		Weapons.SpawnGrenade(player, grenadeTool, weaponSettings, spawnCFrame, impulseDirection, impulsePower)
	end)

	Events.Stance.OnServerEvent:Connect(function(player: Player, stance: number, lean: number)
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
		if typeof(stance) ~= "number" or typeof(lean) ~= "number" then
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
		local character = player.Character
		if not character then
			return
		end

		if victim then
			if victim == player or not victim.Character then
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

