return function(Tycoon, dependencies)
	local Players = dependencies.Players
	local Cleanup = dependencies.Cleanup
        local CollectionService = dependencies.CollectionService
        local ReplicatedStorage = dependencies.ReplicatedStorage
	local ClientSignals = dependencies.ClientSignals
	local Diagnostics = dependencies.Diagnostics
	local IsPromptReachable = dependencies.IsPromptReachable
        local ECS = require(ReplicatedStorage.ECS)

	function Tycoon:_SetupElectricity()
		local fuseBox = self.Stages.Stage2.ScientificLab.FUSE_BOX.FuseBox
		local leverPart = fuseBox.FuseLeaver:FindFirstChild("Part")
		local prompt = leverPart and leverPart:FindFirstChildWhichIsA("ProximityPrompt", true)

		--self.PurchasedItems.ChildAdded:Connect(function(child)
		--	--end -- misleading since we are looking if you turned on the elaver
		--end)

		if prompt then
			prompt.Triggered:Connect(function(player)
				if player ~= self.Owner then
					Diagnostics.reject(player, "Tycoon.Electricity", `Attempted to use another player's fuse box in {self.Model.Name}`)
					return
				end
				if not IsPromptReachable(player, prompt) then
					Diagnostics.reject(player, "Tycoon.Electricity", "Prompt was activated outside its allowed range")
					return
				end
				if player:GetAttribute("Power") then
					if ClientSignals then
						ClientSignals.Send(player, "AlreadyOn")
					end
					return
				end

				if not self.PurchasedItems:FindFirstChild("1b") then
					if ClientSignals then
						ClientSignals.Send(player, "Wires")
					end
					return
				end

				player:SetAttribute("Power", true)
				self:_EnableElectricity()
				ClientSignals.Send(self.Owner, "FuseBox")
			end)
		else
			warn(`[ElectricitySystem] Fuse lever prompt missing for {self.Model:GetFullName()}; fuse interaction skipped.`)
		end

		for _, part in ipairs(self.Model:GetDescendants()) do
			if part:IsA("BasePart") and CollectionService:HasTag(part, "ElectricityParts") then
				part.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if not player or not player:GetAttribute("Power") then
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
				part.Brightness = 0.09
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
                                delay = 0.2,
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
                                delay = 0.3,
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
                                                        amount = 60,
                                                        source = self.Model,
                                                },
                                        })

                                        local lightning = self.VisualEffects.Lightining:Clone()
                                        lightning.Parent = humanoidRootPart
                                        Cleanup.destroyLater(lightning, 4)

                                        local velocity = Instance.new("BodyVelocity")
                                        velocity.MaxForce = Vector3.new(1e5, 0, 1e5)
                                        velocity.Velocity = -humanoidRootPart.CFrame.LookVector * 50
                                        velocity.Parent = humanoidRootPart
                                        Cleanup.destroyLater(velocity, 1.5)

                                        if self.RagdollModule then
                                                self.RagdollModule.Ragdoll(player, 4)
                                        end

                                        local sound = script.Parent.Parent.Parent:FindFirstChild("Electrified")
                                        if sound then
                                                local soundClone = sound:Clone()
                                                soundClone.Parent = humanoidRootPart
                                                soundClone:Play()
                                                Cleanup.destroyLater(soundClone, soundClone.TimeLength)
                                        end

                                        if ClientSignals and self.Owner then
                                                ClientSignals.Send(self.Owner, "Electrocuted")
                                        end
                                end,
                        },
                })

                ECS.createEntity({
                        Name = `{player.Name}:ElectrifyCooldown`,
                        Tycoon = self,
                        ScheduledTask = {
                                delay = 5,
                                elapsed = 0,
                                callback = function()
                                        self.PlayerService:SetElectrified(player, false)
                                end,
                        },
                })
        end
end
