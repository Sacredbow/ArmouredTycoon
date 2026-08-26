--!strict
--[[
	@class ArmourSystem

	@desc
	Armour pickup areas in Stage1. When the tycoon owner touches a pickup,
	the matching vest model is welded to their character and MaxHealth is
	increased. Only one vest can be equipped at a time (PlayerRuntimeState guard).
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

--// Micro-Optimisations

const math_rad = math.rad

--// Constants

const VEST1_HEALTH = 50
const VEST2_HEALTH = 120

--// Internal Utilities

-- Vests are cloned at equip time so they survive player death/respawn
-- (a vest parented to a character is destroyed with that character).
local function EquipVest(Character: Model, VestTemplate: Model, HealthBonus: number)
	const Vest = VestTemplate:Clone()

	const Hum = Character:FindFirstChildOfClass("Humanoid")
	if Hum then
		Hum.MaxHealth += HealthBonus
		Hum.Health += HealthBonus
	end

	const Torso = (Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")) :: BasePart?
	if Torso and Vest.PrimaryPart then
		Vest.Parent = Character
		const Offset = CFrame.new(0, 0.2, 0) * CFrame.Angles(math_rad(-5), 0, 0)
		Vest:PivotTo(Torso.CFrame * Offset)
		const NewWeld = Instance.new("WeldConstraint")
		NewWeld.Part0 = Torso
		NewWeld.Part1 = Vest.PrimaryPart
		NewWeld.Parent = Vest.PrimaryPart
	end
end

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Methods — Setup

	function Tycoon:_SetupArmour()
		const Armour1 = self.Stages.Stage1:FindFirstChild("Armour1")
		const Armour2 = self.Stages.Stage1:FindFirstChild("Armour2")
		if not Armour1 or not Armour2 then
			return
		end

		-- Pass the source templates; EquipVest clones them at equip time.
		const ArmourVest1 = ReplicatedStorage.Assets.CharacterItems.Armour.Armour1 :: Model
		const ArmourVest2 = ReplicatedStorage.Assets.CharacterItems.Armour.Armour2 :: Model

		const Armour1Part = Armour1:FindFirstChild("Part") :: BasePart?
		if Armour1Part then
			Armour1Part.Touched:Connect(function(Hit: Instance)
				const Player = Players:GetPlayerFromCharacter(Hit.Parent)
				if not Player or Player ~= self.Owner then
					return
				end
				if Armour1Part.Transparency ~= 0 then
					return
				end
				if PlayerRuntimeState.HasArmourEquipped(Player) then
					return
				end

				const Char = Player.Character
				if not Char then
					return
				end

				PlayerRuntimeState.SetArmourEquipped(Player, true)
				EquipVest(Char, ArmourVest1, VEST1_HEALTH)
			end)
		end

		const Armour2Part = Armour2:FindFirstChild("Part") :: BasePart?
		if Armour2Part then
			Armour2Part.Touched:Connect(function(Hit: Instance)
				const Player = Players:GetPlayerFromCharacter(Hit.Parent)
				if not Player or Player ~= self.Owner then
					return
				end
				if Armour2Part.Transparency ~= 0 then
					return
				end
				if PlayerRuntimeState.HasArmourEquipped(Player) then
					return
				end

				const Char = Player.Character
				if not Char then
					return
				end

				PlayerRuntimeState.SetArmourEquipped(Player, true)
				EquipVest(Char, ArmourVest2, VEST2_HEALTH)
			end)
		end
	end
end

