--!strict
--[[
	@class ElectricitySystem

	@desc
	Manages the fuse box power toggle, electrified water/parts, and player electrocution.
	Power state is tracked via PlayerRuntimeState.
]]

--// Services

const CollectionService = game:GetService("CollectionService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Packets = require(ReplicatedStorage.Network.Packets)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
const ValidatePromptRange = require(script.Parent.Parent.Parent.Utilities.ValidatePromptRange)
const Cleanup = require(script.Parent.Parent.Parent.Utilities.Cleanup)

--// Constants

const ELECTRIFY_DISARM_DELAY = 0.2
const ELECTRIFY_IMPACT_DELAY = 0.3
const ELECTRIFY_COOLDOWN = 5
const ELECTRIFY_DAMAGE = 60
const BODY_VELOCITY_FORCE = 1e5
const BODY_VELOCITY_MULTIPLIER = 50
const RAGDOLL_DURATION = 4
const LIGHTNING_LIFETIME = 4
const VELOCITY_LIFETIME = 1.5
const POWER_LIGHT_BRIGHTNESS = 0.09

--// Module

return function(Tycoon, _Dependencies: { [string]: any })

	--// Internal Methods

	local function SendToast(player: Player?, toastType: string, message: string?)
		if player then
			Packets.packets.Notification.sendTo({
				["type"] = toastType,
				message = message,
			}, player)
		end
	end

	function Tycoon:_SetupElectricity()
		local fuseBox = self.Stages.Stage2.ScientificLab.FUSE_BOX.FuseBox
		local leverPart = fuseBox.FuseLeaver:FindFirstChild("Part")
		local prompt = leverPart and leverPart:FindFirstChildWhichIsA("ProximityPrompt", true)

		if prompt then
			prompt.Triggered:Connect(function(player)
				if player ~= self.Owner then
					warn(`[Electricity] {player.Name} attempted to use another player's fuse box in {self.Model.Name}`)
					return
				end
				if not ValidatePromptRange(player, prompt) then
					warn(`[Electricity] {player.Name} activated prompt outside allowed range in {self.Model.Name}`)
					return
				end
				if PlayerRuntimeState.HasPower(player) then
					SendToast(player, "info", "Power is already on")
					return
				end

				if not self.PurchasedItems:FindFirstChild("1b") then
					SendToast(player, "info", "Find the wires first")
					return
				end

				PlayerRuntimeState.SetPower(player, true)
				self:_EnableElectricity()
				SendToast(self.Owner, "success", "Power restored")
			end)
		else
			warn(`[ElectricitySystem] Fuse lever prompt missing for {self.Model:GetFullName()}; fuse interaction skipped.`)
		end

		for _, part in ipairs(self.Model:GetDescendants()) do
			if part:IsA("BasePart") and CollectionService:HasTag(part, "ElectricityParts") then
				part.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if not player or not PlayerRuntimeState.HasPower(player) then
						return
					end

					if self.PlayerService:IsElectrified(player) then
						return
					end

					self:_ElectrifyPlayer(player)
				end)
			end
		end
	end

	function Tycoon:_EnableElectricity()
		for _, part in ipairs(self.PurchasedItems:GetDescendants()) do
			if part:IsA("BasePart") and part:FindFirstChild("SwitchLight") then
				part.Material = Enum.Material.Neon
				part.BrickColor = BrickColor.new("Institutional white")
			end
			if part:IsA("PointLight") then
				part.Brightness = POWER_LIGHT_BRIGHTNESS
			end
			if CollectionService:HasTag(part, "ElectricityParts") then
				part.Material = Enum.Material.Neon
			end
			if CollectionService:HasTag(part, "Power") and part:IsA("ParticleEmitter") then
				part.Enabled = true
			end
		end
	end

	function Tycoon:_ElectrifyPlayer(player: Player)
		self.PlayerService:SetElectrified(player, true)

		local character = player.Character
		if not character then
			self.PlayerService:SetElectrified(player, false)
			return
		end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then
			self.PlayerService:SetElectrified(player, false)
			return
		end

		humanoid:UnequipTools()

		ECS.createEntity({
			Name = `{player.Name}:ElectrifyDisarm`,
			Tycoon = self,
			ScheduledTask = {
				delay = ELECTRIFY_DISARM_DELAY,
				elapsed = 0,
				callback = function()
					local currentCharacter = player.Character
					if not currentCharacter then
						return
					end

					local animBase = currentCharacter:FindFirstChild("AnimBase")
					if player.Backpack then
						for _, tool in ipairs(player.Backpack:GetChildren()) do
							if tool:IsA("Tool") then
								tool:Destroy()
								if animBase then
									animBase:Destroy()
								end
							end
						end
					end

					for _, tool in ipairs(currentCharacter:GetChildren()) do
						if tool:IsA("Tool") then
							tool:Destroy()
							if animBase then
								animBase:Destroy()
							end
						end
					end

					local backup = ReplicatedStorage.ACS_Engine.GunModels
					for _, model in backup:GetChildren() do
						local hiddenGun: Model = currentCharacter:FindFirstChild(model.Name) or currentCharacter:FindFirstChild("S" .. model.Name)
						if hiddenGun then
							hiddenGun:Destroy()
						end
					end
				end,
			},
		})

		ECS.createEntity({
			Name = `{player.Name}:ElectrifyImpact`,
			Tycoon = self,
			ScheduledTask = {
				delay = ELECTRIFY_IMPACT_DELAY,
				elapsed = 0,
				callback = function()
					local currentCharacter = player.Character
					if not currentCharacter then
						return
					end

					local currentHumanoid = currentCharacter:FindFirstChild("Humanoid") :: Humanoid?
					local humanoidRootPart = currentCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
					if not currentHumanoid or not humanoidRootPart then
						return
					end

					ECS.createEntity({
						Name = `{player.Name}:ElectricityDamage`,
						DamageRequest = {
							humanoid = currentHumanoid,
							amount = ELECTRIFY_DAMAGE,
							source = self.Model,
						},
					})

					local lightning = self.VisualEffects.Lightining:Clone()
					lightning.Parent = humanoidRootPart
					Cleanup.destroyLater(lightning, LIGHTNING_LIFETIME)

					local velocity = Instance.new("BodyVelocity")
					velocity.MaxForce = Vector3.new(BODY_VELOCITY_FORCE, 0, BODY_VELOCITY_FORCE)
					velocity.Velocity = -humanoidRootPart.CFrame.LookVector * BODY_VELOCITY_MULTIPLIER
					velocity.Parent = humanoidRootPart
					Cleanup.destroyLater(velocity, VELOCITY_LIFETIME)

					if self.RagdollModule then
						self.RagdollModule.Ragdoll(player, RAGDOLL_DURATION)
					end

					local sound = script.Parent.Parent.Parent.Parent:FindFirstChild("Electrified")
					if sound then
						local soundClone = sound:Clone()
						soundClone.Parent = humanoidRootPart
						soundClone:Play()
						Cleanup.destroyLater(soundClone, soundClone.TimeLength)
					end

					SendToast(self.Owner, "error", "You were electrocuted")
				end,
			},
		})

		ECS.createEntity({
			Name = `{player.Name}:ElectrifyCooldown`,
			Tycoon = self,
			ScheduledTask = {
				delay = ELECTRIFY_COOLDOWN,
				elapsed = 0,
				callback = function()
					self.PlayerService:SetElectrified(player, false)
				end,
			},
		})
	end
end
