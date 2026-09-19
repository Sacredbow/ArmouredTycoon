--!strict
--[[
	@class InteractionSystem

	@desc
	Collision setup for NPC/armour models (via CollisionManager) and the
	Lakester reload prompt that refills the owner's weapon ammo.
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ReloadConfig = require(script.Parent.ReloadConfig)
const ValidatePromptRange = require(script.Parent.Parent.Parent.Utilities.ValidatePromptRange)
const Notify = require(script.Parent.Parent.Parent.Utilities.Notify)

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Methods — Setup Collision

	function Tycoon:_SetupCollision()
		const Stage1 = self.Stages:FindFirstChild("Stage1")
		if not Stage1 then
			return
		end

		const Armour1 = Stage1:FindFirstChild("Armour1") and Stage1.Armour1:FindFirstChild("Character")
		const Armour2 = Stage1:FindFirstChild("Armour2") and Stage1.Armour2:FindFirstChild("Character")
		const AmmoArea = Stage1:FindFirstChild("AmmoArea")

		if AmmoArea then
			const Lakester = AmmoArea:FindFirstChild("Lakester")
			if Lakester then
				if Armour1 then
					self.CollisionManager.SetNonCollidable(Armour1, false)
				end
				if Armour2 then
					self.CollisionManager.SetNonCollidable(Armour2, false)
				end
				self.CollisionManager.SetNonCollidable(Lakester, false)
			end
		end
	end

	--// Internal Methods — Reload Prompt

	function Tycoon:_ReloadConfiguration()
		if self.ReloadConfigurationConnected then
			return
		end

		const AmmoArea = self.Stages.Stage1:FindFirstChild("AmmoArea")
		if AmmoArea then
			const Lakester = AmmoArea:FindFirstChild("Lakester")
			if Lakester then
				const Requester: BasePart? = Lakester:FindFirstChild("Requester")
				if not Requester then
					return
				end
				const ProximityPrompt = Requester:FindFirstChild("ProximityPrompt")
				if not ProximityPrompt or not ProximityPrompt:IsA("ProximityPrompt") then
					warn(`[Tycoon] Lakester prompt is missing in {self.Model:GetFullName()}`)
					return
				end

				(ProximityPrompt :: ProximityPrompt).Triggered:Connect(function(Player: Player)
					if Player ~= self.Owner then
						warn(`[Tycoon] {Player.Name} attempted to use another player's Lakester in {self.Model.Name}`)
						Notify(Player, "error", "Only the tycoon owner can reload here.")
						return
					end
					if not ValidatePromptRange(Player, ProximityPrompt :: ProximityPrompt) then
						warn(`[Tycoon] {Player.Name} activated prompt outside allowed range in {self.Model.Name}`)
						Notify(Player, "info", "Move closer to reload your weapon.")
						return
					end
					ReloadConfig.onPromptTriggered(Player)
				end)
				self.ReloadConfigurationConnected = true
			end
		end
	end
	

end

