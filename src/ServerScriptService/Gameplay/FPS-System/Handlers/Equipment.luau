--!strict
-- ACS equipment requests. Authored settings and transforms are loaded on the server.

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const WeaponDefinitionResolver = require(ReplicatedStorage.Shared.Game.Combat.Weapons.Resolver)

const Weapons = require(script.Parent.Parent.Core.Weapons)
const NetworkGuard = require(script.Parent.Parent.Parent.Services.Networking.NetworkGuard)

const EQUIP_POLICY = { Rate = 12, Burst = 20 }

function Bind()
	NetworkGuard.Listen(Packets.packets.EquipIntent, "ACSCombat.EquipIntent", EQUIP_POLICY, function(data, player)
		local weapon = data.weapon
		local mode = data.mode
		if typeof(mode) ~= "number" or mode ~= math.floor(mode) or (mode ~= 1 and mode ~= 2) then
			return
		end
		if typeof(weapon) ~= "Instance" or not weapon:IsA("Tool") then
			return
		end

		if mode == 2 then
			Weapons.Equip(player, weapon, mode, nil, {})
			return
		end
		local character = player.Character
		if mode ~= 1 or not character or weapon.Parent ~= character then
			return
		end
		WeaponDefinitionResolver.assignId(weapon)
		const settings = WeaponDefinitionResolver.getSettingsData(weapon)
		const animations = WeaponDefinitionResolver.getAnimationsData(weapon)
		if type(settings) ~= "table"
			or type(animations) ~= "table"
			or typeof(animations.SV_RightArmPos) ~= "CFrame"
			or typeof(animations.SV_LeftArmPos) ~= "CFrame"
			or typeof(animations.SV_GunPos) ~= "CFrame" then
			return
		end


		Weapons.Equip(player, weapon, mode, settings, animations)
	end)
end

return {
	Bind = Bind,
}
