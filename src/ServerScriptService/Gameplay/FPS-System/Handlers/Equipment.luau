--!strict
--[[
	@class FPSEquipment

	@desc
	Wires the Equip / RefillMag remotes to the Weapons module with
	minimal player & tool validation.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const Weapons = require(script.Parent.Parent.Core.Weapons)

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const Events = Engine:WaitForChild("Events") :: any

--// Public API

function Bind()
	Events.Equip.OnServerEvent:Connect(function(
		player: Player,
		weapon: Tool?,
		mode: number,
		settings: any,
		anim: { [string]: CFrame }?
	)
		if not player.Character then
			return
		end

		if not weapon or not weapon:IsA("Tool") then
			warn(`[FPS.Equipment] {player.Name} sent equip without a valid tool`)
			return
		end

		if mode ~= 1 and mode ~= 2 then
			warn(`[FPS.Equipment] {player.Name} sent invalid equip mode {tostring(mode)}`)
			return
		end

		-- Ownership check: a player may only equip a tool they actually have.
		local character = player.Character
		local backpack = player:FindFirstChildOfClass("Backpack")
		local ownsWeapon = (character ~= nil and weapon:IsDescendantOf(character))
			or (backpack ~= nil and weapon:IsDescendantOf(backpack))
		if not ownsWeapon then
			warn(`[FPS.Equipment] {player.Name} attempted to equip an unowned weapon: {weapon:GetFullName()}`)
			return
		end

		local hasValidTransforms = type(anim) == "table"
			and typeof(anim.SV_RightArmPos) == "CFrame"
			and typeof(anim.SV_LeftArmPos) == "CFrame"
			and typeof(anim.SV_GunPos) == "CFrame"
		if mode == 1 and not hasValidTransforms then
			warn(`[FPS.Equipment] {player.Name} sent equip mode 1 without valid animation transforms`)
			return
		end

		Weapons.Equip(player, weapon, mode, settings, anim or {})
	end)

	Events.RefillMag.OnServerEvent:Connect(function(player: Player, weapon: Tool?)
		Weapons.RefillAllMags(player, weapon)
	end)
end

return {
	Bind = Bind,
}

