--!strict
--[[
	@class TeleportSystem

	@desc
	Teleporters between stages. When the tycoon owner triggers a teleporter
	prompt, their character is moved to the target ground position, preserving
	their yaw rotation. Connections are stored for cleanup on rebirth/leave.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const Packets = require(ReplicatedStorage.Network.Packets)
const ValidatePromptRange = require(script.Parent.Parent.Parent.Utilities.ValidatePromptRange)
const Notify = require(script.Parent.Parent.Parent.Utilities.Notify)

--// Micro-Optimisations

const Vector3_new = Vector3.new

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Methods — Setup

	function Tycoon:_SetupTeleportation()
		self.TeleportConnections = self.TeleportConnections or {}
		for _, Connection in self.TeleportConnections do
			Connection:Disconnect()
		end
		table.clear(self.TeleportConnections)

		for _, TeleportModel : Model in (self.Stages :: any):GetDescendants() do
			if not TeleportModel:HasTag("Teleporters") then 
				continue
			end
			if not TeleportModel:IsA("Model") then
				continue
			end

			const TeleportPart = TeleportModel:FindFirstChild("Teleport")
			if not TeleportPart or not TeleportPart:IsA("BasePart") then
				warn(`Could not find the Teleport part for the teleportation model: {TeleportModel:GetFullName()}`)
				continue
			end

			const TeleportPrompt = TeleportPart:FindFirstChild("TeleportPrompt")
			if not TeleportPrompt or not TeleportPrompt:IsA("ProximityPrompt") then
				warn(`Could not find the TeleportPrompt for {TeleportPart:GetFullName()}`)
				continue
			end

			const PromptConnection = TeleportPrompt.Triggered:Connect(function(Player: Player)
				if self.Owner ~= Player then
					Notify(Player, "error", "Only the tycoon owner can use this teleporter.")
					return
				end
				if not ValidatePromptRange(Player, TeleportPrompt :: ProximityPrompt) then
					warn(`[Tycoon] {Player.Name} activated teleporter outside allowed range in {self.Model.Name}`)
					Notify(Player, "info", "Move closer to use the teleporter.")
					return
				end

				const Character = Player.Character
				if not Character then
					return
				end

				const HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
				if not HumanoidRootPart or not HumanoidRootPart:IsA("BasePart") then
					return
				end

				const Yaw = select(2, HumanoidRootPart.CFrame:ToEulerAnglesYXZ())
				const GroundPosition = (TeleportPart :: BasePart).Position - Vector3_new(0, (TeleportPart :: BasePart).Size.Y / 2, 0)
				self.PlayerService:AllowServerTeleport(Player, 0.5)
				Character:PivotTo(CFrame.new(GroundPosition) * CFrame.Angles(0, Yaw, 0))
				Packets.packets.Notification.sendTo({ ["type"] = "info", message = `Teleporting...`, RequiresFade = true
				}, Player)
				
				task.wait(1.5)
				self.PlayerService:AllowServerTeleport(Player, 0.4)
				Character:PivotTo(TeleportModel.SpawnPoint.CFrame)
			end)

			table.insert(self.TeleportConnections, PromptConnection)
		end
	end
end

