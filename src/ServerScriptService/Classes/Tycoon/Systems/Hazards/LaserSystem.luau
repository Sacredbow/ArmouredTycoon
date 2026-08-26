--!strict
--[[
	@class LaserSystem

	@desc
	Laser traps in Stage4. When a non-owner touches a visible (enabled) laser,
	they take lethal damage. The tycoon owner is immune.
]]

--// Services

const Players = game:GetService("Players")

--// Constants

const LaserDamage = math.huge

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Methods — Setup

	function Tycoon:_SetupLasers()
		const Lasers = self.Stages.Stage4:FindFirstChild("Lasers")
		if not Lasers then
			return
		end

		for _, Laser in Lasers:GetChildren() do
			if not Laser:IsA("BasePart") then
				continue
			end
			Laser.Touched:Connect(function(Hit: Instance)
				if Laser.Transparency ~= 0 then
					return
				end

				const Player = Players:GetPlayerFromCharacter(Hit.Parent)
				if Player then
					if self.Owner == Player then
						return
					end

					const Character = Player.Character
					if not Character then
						return
					end
					const Hum = Character:FindFirstChildOfClass("Humanoid")
					if Hum then
						Hum:TakeDamage(LaserDamage)
					end
				end
			end)
		end
	end
end

