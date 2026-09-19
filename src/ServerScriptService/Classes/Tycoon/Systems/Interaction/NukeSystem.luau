--!strict
--[[
	@class NukeSystem

	@desc
	ButtonStand nuke launcher. Only the tycoon owner can activate the launch
	prompt, within prompt range, and only once per 1200-second cooldown.
	Delegates to RocketSystem for flight and targeting.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const RocketSystem = require(script.Parent.Parent.Combat.Rocket)
const ValidatePromptRange = require(script.Parent.Parent.Parent.Utilities.ValidatePromptRange)
const Notify = require(script.Parent.Parent.Parent.Utilities.Notify)

--// Constants

const NUKE_COOLDOWN = 1200

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Methods — Setup

	function Tycoon:_SetupProximityPrompts()
		local Debounce = false

		if not self.Components then
			return
		end
		const ButtonStand = self.Components:FindFirstChild("ButtonStand")
		if not ButtonStand then
			return
		end
		const ActivatePrompt = ButtonStand.Button:FindFirstChild("Activate")
		if not ActivatePrompt or not ActivatePrompt:IsA("ProximityPrompt") then
			warn(`[Tycoon] Activate prompt is missing in {self.Model:GetFullName()}`)
			return
		end
		const ActivateNuke = ActivatePrompt :: ProximityPrompt

		ActivateNuke.Triggered:Connect(function(Player: Player)
			if Player ~= self.Owner then
				warn(`[Tycoon] {Player.Name} attempted to activate another player's nuke in {self.Model.Name}`)
				Notify(Player, "error", "Only the tycoon owner can launch this nuke.")
				return
			end
			if not ValidatePromptRange(Player, ActivateNuke) then
				warn(`[Tycoon] {Player.Name} activated nuke prompt outside allowed range in {self.Model.Name}`)
				Notify(Player, "info", "Move closer to launch the nuke.")
				return
			end
			if Debounce then
				Notify(Player, "info", "The nuke launcher is recharging.")
				return
			end

			const Rocket = RocketSystem.new(self.Rocket, Player, self.PlayerService, (self.Audios :: any).NuclearAudios, Tycoon.Registry)
			self.PlayerService:ActivateRocket(Player, true)
			Rocket:Init()
			Debounce = true
			(ButtonStand :: any).Button.BrickColor = BrickColor.new("Really red")
			self.PlayerService:ActivateRocket(Player, false)

			ECS.createEntity({
				Name = `{self.Model.Name}:NukeCooldown`,
				Tycoon = self,
				ScheduledTask = {
					delay = NUKE_COOLDOWN,
					elapsed = 0,
					callback = function()
						Debounce = false
						if ButtonStand.Parent and ButtonStand.Button then
							(ButtonStand :: any).Button.BrickColor = BrickColor.new("Bright green")
						end
					end,
				},
			})
		end)
	end
end

