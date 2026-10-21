--!strict
-- ACS equipment requests. Authored settings and transforms are loaded on the server.

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Weapons = require(script.Parent.Parent.Core.Weapons)

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const Events = Engine:WaitForChild("Events") :: any

function Bind()
	Events.Equip.OnServerEvent:Connect(function(player: Player, weapon: Tool?, mode: number)
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

		local settingsModule = weapon:FindFirstChild("ACS_Settings")
		local animationsModule = weapon:FindFirstChild("ACS_Animations")
		if not settingsModule or not settingsModule:IsA("ModuleScript")
			or not animationsModule or not animationsModule:IsA("ModuleScript") then
			return
		end

		local settingsOk, settings = pcall(require, settingsModule)
		local animationsOk, animations = pcall(require, animationsModule)
		if not settingsOk or type(settings) ~= "table"
			or not animationsOk or type(animations) ~= "table"
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
