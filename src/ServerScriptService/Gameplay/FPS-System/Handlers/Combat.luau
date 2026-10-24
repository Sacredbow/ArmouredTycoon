--!strict
--[[
	@class FPSCombat

	@desc
	Wires gameplay-authoritative remotes for the ACS engine: damage and stance. Each handler validates the request before delegating to the Damage and Weapons core modules.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const Damage = require(script.Parent.Parent.Core.Damage)
const Weapons = require(script.Parent.Parent.Core.Weapons)
const NetworkGuard = require(ServerScriptService.Services.Networking.NetworkGuard)

--// Engine Folders


--// Constants


const SHIELD_HIT_POLICY = { Rate = 25, Burst = 40 }
const DAMAGE_POLICY = { Rate = 25, Burst = 40 }
const STANCE_POLICY = { Rate = 20, Burst = 30 }


--// Public API

function Bind()
	NetworkGuard.Listen(Packets.packets.ShieldHitIntent, "ACSCombat.ShieldHitIntent", SHIELD_HIT_POLICY, function(data, player)
		Damage.HandleShieldHit(player, data.shield)
	end)

	NetworkGuard.Listen(Packets.packets.DamageIntent, "ACSCombat.DamageIntent", DAMAGE_POLICY, function(data, player)
		local weapon = data.weapon
		local targetHumanoid = data.targetHumanoid
		local hitPart = data.hitPart
		local hitType = data.hitType
		Damage.HandleDamageRequest(
			player,
			weapon,
			targetHumanoid,
			hitPart,
			hitType
		)
	end)

	NetworkGuard.Listen(Packets.packets.StanceIntent, "ACSCombat.StanceIntent", STANCE_POLICY, function(data, player)
		local stance = data.stance
		local lean = data.lean
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
	end
end

return {
	Bind = Bind,
}

