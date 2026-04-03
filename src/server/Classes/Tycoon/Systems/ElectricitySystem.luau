return function(Tycoon, dependencies)
	local Players = dependencies.Players
	local Debris = dependencies.Debris
	local CollectionService = dependencies.CollectionService
	local ReplicatedStorage = dependencies.ReplicatedStorage
	local ReturnRequest = dependencies.ReturnRequest

	function Tycoon:_SetupElectricity()
		local fuseBox = self.Stages.Stage2.ScientificLab.FUSE_BOX.FuseBox
		local prompt = fuseBox.FuseLeaver.Part.ProximityPrompt

		self.PurchasedItems.ChildAdded:Connect(function(child)
			if child.Name == "CeilingLights1" and ReturnRequest and self.OwnerValue.Value then
				ReturnRequest:FireClient(self.OwnerValue.Value, "FuseBox")
			end
		end)

		prompt.Triggered:Connect(function(player)
			if player:GetAttribute("Power") then
				if ReturnRequest then
					ReturnRequest:FireClient(player, "AlreadyOn")
				end
				return
			end

			if not self.PurchasedItems:FindFirstChild("1b") then
				if ReturnRequest then
					ReturnRequest:FireClient(player, "Wires")
				end
				return
			end

			player:SetAttribute("Power", true)
			self:_EnableElectricity()
		end)

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
			return
		end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then
			return
		end

		humanoid:UnequipTools()

		task.wait(0.2)

		local animBase = character:FindFirstChild("AnimBase")
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

		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				tool:Destroy()

				if animBase then
					animBase:Destroy()
				end
			end
		end

		local backup = ReplicatedStorage.ACS_Engine.GunModels

		for _, model in backup:GetChildren() do
			local hiddenGun: Model = character:FindFirstChild(model.Name) or character:FindFirstChild("S" .. model.Name)
			if hiddenGun then
				hiddenGun:Destroy()
			end
		end

		task.wait(0.1)

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end

		humanoid:TakeDamage(60)

		local lightning = self.VisualEffects.Lightining:Clone()
		lightning.Parent = humanoidRootPart
		Debris:AddItem(lightning, 4)

		local velocity = Instance.new("BodyVelocity")
		velocity.MaxForce = Vector3.new(1e5, 0, 1e5)
		velocity.Velocity = -humanoidRootPart.CFrame.LookVector * 50
		velocity.Parent = humanoidRootPart
		Debris:AddItem(velocity, 1.5)

		if self.RagdollModule then
			self.RagdollModule.Ragdoll(player, 4)
		end

		local sound = script.Parent.Parent.Parent:FindFirstChild("Electrified")
		if sound then
			local soundClone = sound:Clone()
			soundClone.Parent = humanoidRootPart
			soundClone:Play()
			Debris:AddItem(soundClone, soundClone.TimeLength)
		end

		if ReturnRequest and self.OwnerValue.Value then
			ReturnRequest:FireClient(self.OwnerValue.Value, "Electrocuted")
		end

		task.delay(5, function()
			self.PlayerService:SetElectrified(player, false)
		end)
	end
end
