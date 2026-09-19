--!strict
--[[
	@class GunSystem

	@desc
	Gun pickup prompts on GunModels. When the tycoon owner activates a gun's
	prompt, the matching tool is cloned from ServerStorage.Guns into their
	Backpack. Duplicate prevention scans Backpack, StarterGear, and Character.
]]

--// Services

const Players = game:GetService("Players")
const ServerStorage = game:GetService("ServerStorage")

--// Modules

const ValidatePromptRange = require(script.Parent.Parent.Parent.Utilities.ValidatePromptRange)
const Notify = require(script.Parent.Parent.Parent.Utilities.Notify)

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Methods — Setup

	function Tycoon:_SetupGuns()
		for _, GunModel in self.GunModels:GetChildren() do
			const Requester = GunModel:FindFirstChild("Requester")
			if not Requester then
				continue
			end
			const ProximityPrompt = Requester:FindFirstChild("ProximityPrompt") :: ProximityPrompt?
			if not ProximityPrompt then
				continue
			end

			ProximityPrompt.Triggered:Connect(function(Player: Player)
				if Player ~= self.Owner then
					warn(`[Tycoon] {Player.Name} attempted to collect a weapon from {self.Model.Name}`)
					Notify(Player, "error", "Only the tycoon owner can collect this weapon.")
					return
				end
				if not ValidatePromptRange(Player, ProximityPrompt) then
					warn(`[Tycoon] {Player.Name} activated gun prompt outside allowed range in {self.Model.Name}`)
					Notify(Player, "info", "Move closer to collect this weapon.")
					return
				end

				const GunName = GunModel.Name
				const Character = Player.Character
				if Player.Backpack:FindFirstChild(GunName) or Player.StarterGear:FindFirstChild(GunName) or (Character and Character:FindFirstChild(GunName)) then
					    Notify(Player, "info", "You already have this weapon.")
					    return
				end

				const Gun = ServerStorage.Guns:FindFirstChild(GunName)
				if Gun then
					const GunClone = Gun:Clone()
					GunClone.Parent = Player.Backpack
				else
					warn(`[Tycoon] ServerStorage.Guns is missing the required {GunName} template`)
				end
			end)
		end
	end
end

