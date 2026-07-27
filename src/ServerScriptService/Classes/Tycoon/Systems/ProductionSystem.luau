local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

local DROPPER_VALUES = {
	GoldenDropper = 85,
	EliteDropper = 225,
}

local DEFAULT_DROPPER_VALUE = 15
local DEFAULT_PRODUCTION_INTERVAL = 2.5

local function isRenderablePart(instance)
	return instance:IsA("BasePart")
end

local function getNumericMultiplier(player: Player): number
	return PlayerRuntimeState.GetMultiplier(player)
end


return function(Tycoon, dependencies)
	local TweenService = dependencies.TweenService
	local CollectionService = dependencies.CollectionService
	local Cleanup = dependencies.Cleanup

	function Tycoon:_SetupAmmoArea(dropper)
		local lakesterModel = dropper:FindFirstChild("Lakester")
		if not lakesterModel then
			return
		end

		self.CollisionManager.NonCollidable(lakesterModel, true)

		local humanoid = lakesterModel:FindFirstChild("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid

			local track = animator:LoadAnimation(self.NPC_IdleAnimation)
			track.Looped = true
			track:Play()
		end

		for _, descendant in ipairs(lakesterModel:GetDescendants()) do
			if isRenderablePart(descendant) then
				descendant.Transparency = 0
			end
		end

		for _, descendant in ipairs(dropper:GetDescendants()) do
			if not descendant:IsA("BasePart") then
				continue
			end

			if descendant:IsDescendantOf(lakesterModel) then
				continue
			end

			if descendant.Name == "Requester" then
				descendant.Transparency = 1
				descendant.CanCollide = false
				continue
			end

			descendant.CanCollide = true
			if descendant.Name == "HumanoidRootPart" then
				descendant.Transparency = 1
			end
		end
	end

        function Tycoon:_ApplyFadeStep(descendant, progress)
		if descendant:IsA("Texture") then
			descendant.Transparency = 0.45
		end

		if descendant:IsA("ParticleEmitter") and not CollectionService:HasTag(descendant, "SelfEnabling") then
			descendant.Enabled = true
		end

		if descendant:IsA("Decal") then
			descendant.Transparency = 1 - progress
		end

		if descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			descendant.Enabled = true
		end

		if descendant:IsA("ProximityPrompt") then
			if CollectionService:HasTag(descendant, "SelfEnabling") then
				return true
			end

			descendant.Enabled = true
		end

		if not isRenderablePart(descendant) then
			return true
		end

		if descendant.Name == "HumanoidRootPart" then
			descendant.Transparency = 1
			descendant.CanCollide = false
			return true
		end

		if descendant.Name == "Window" then
			descendant.Transparency = 0.65
			descendant.CanCollide = false
			return true
		end

		if CollectionService:HasTag(descendant, "LowTransparency") then
			descendant.Transparency = 0.65
			descendant.CanCollide = true
			return true
		end

		if CollectionService:HasTag(descendant, "Invisible") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			return true
		end

		if descendant.Parent.Name == "" then
			descendant.Transparency = 0.2
			return true
		end

		descendant.Transparency = 1 - progress
		descendant.CanCollide = not CollectionService:HasTag(descendant, "NonCollidable")
		return true
	end

        function Tycoon:_GetDropperBaseValue(dropper)
		return DROPPER_VALUES[dropper.Name] or DEFAULT_DROPPER_VALUE
	end

	function Tycoon:_CreateDropperVisual(dropper, spawnPart)
		local conveyor = self.MainItems:FindFirstChild("Conveyor1")
		if not conveyor then
			return
		end

		local movingPart = conveyor:FindFirstChild("MovingPart")
		local collector = conveyor:FindFirstChild("Collector")
		if not movingPart or not movingPart:IsA("BasePart") then
			return
		end

		local part = Instance.new("Part")
		part.Name = "DropperVisual"
		part.Size = Vector3.new(1, 1, 1)
		part.Shape = Enum.PartType.Block
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = spawnPart.CFrame
		part.Parent = self.DropperVisualsFolder

		if dropper.Name == "GoldenDropper" then
			part.Color = BrickColor.new("Gold").Color
		elseif dropper.Name == "EliteDropper" then
			part.Color = BrickColor.new("Royal purple").Color
		else
			part.Color = BrickColor.new("Lime green").Color
		end

		local conveyorY = movingPart.Position.Y + (movingPart.Size.Y * 0.5) + (part.Size.Y * 0.5)
		local dropTargetPosition = Vector3.new(spawnPart.Position.X, conveyorY, spawnPart.Position.Z)
		local startRotation = spawnPart.CFrame - spawnPart.Position
		local conveyorSpeed = 23
		local conveyorDistance = movingPart.Size.Z * 0.5
		local conveyorDirection = movingPart.CFrame.LookVector
		local travelDistance = conveyorDistance

		if collector and collector:IsA("BasePart") then
			local toCollector = collector.Position - dropTargetPosition
			local projectedDistance = toCollector:Dot(conveyorDirection)
			if projectedDistance > 0 then
				travelDistance = projectedDistance
			end
		end

		local collectorTargetPosition = dropTargetPosition + (conveyorDirection * travelDistance)
		local conveyorTweenTime = math.max(travelDistance / conveyorSpeed, 0.1)

		local dropTween = TweenService:Create(
			part,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(dropTargetPosition) * startRotation }
		)
		dropTween:Play()
		dropTween.Completed:Connect(function()
			if not part.Parent then
				return
			end

			local conveyorTween = TweenService:Create(
				part,
				TweenInfo.new(conveyorTweenTime, Enum.EasingStyle.Linear),
				{ CFrame = CFrame.new(collectorTargetPosition) * startRotation }
			)
			conveyorTween:Play()
		end)

		Cleanup.destroyLater(part, 0.35 + conveyorTweenTime + 0.25)
	end

	function Tycoon:_ApplyUpgraderBonus(dropper)
		if self.AppliedUpgraders[dropper] then
			return
		end

		local bonus = nil
		if dropper.Name == "BasicUpgrader" then
			bonus = 2
		elseif dropper.Name == "EnchancedUpgrader" then
			bonus = 3
		end

		if not bonus then
			return
		end

		self.AppliedUpgraders[dropper] = true

		local owner = self.Owner
		if not owner then
			return
		end

		local currentMultiplier = getNumericMultiplier(owner)
		if currentMultiplier == 1 then
			PlayerRuntimeState.SetMultiplier(owner, currentMultiplier * bonus)
		else
			PlayerRuntimeState.SetMultiplier(owner, currentMultiplier + bonus)
		end
	end

	function Tycoon:_StartDropperLoop(dropper)
		local spawnPart = dropper:FindFirstChild("Spawn")
		if not spawnPart or not spawnPart:IsA("BasePart") then
			return
		end

		if self.ActiveDropperLoops[dropper] then
			return
		end

                self.ActiveDropperLoops[dropper] = ECS.createEntity({
                        Name = `{self.Model.Name}:{dropper.Name}:Producer`,
                        Model = dropper,
                        Tycoon = self,
                        Producer = {
                                tycoon = self,
                                dropper = dropper,
                                spawnPart = spawnPart,
                                value = self:_GetDropperBaseValue(dropper),
                                interval = DEFAULT_PRODUCTION_INTERVAL,
                                elapsed = 0,
                        },
                })
        end

        function Tycoon:_StopAllDropperLoops()
                for _, entity in self.ActiveDropperLoops do
                        ECS.deleteEntity(entity)
                end

                table.clear(self.ActiveDropperLoops)
        end

        function Tycoon:_FadeInComplete(dropper, durationOverride)
                local duration = if durationOverride ~= nil then durationOverride else 1
                local targets = { dropper }

                if dropper:IsA("Model") and dropper.Name == "AmmoArea" then
                        self:_SetupAmmoArea(dropper)
                end

                for _, descendant in ipairs(dropper:GetDescendants()) do
                        table.insert(targets, descendant)
                end

                local entity = self.ItemEntities and self.ItemEntities[dropper]
                if not entity then
                        entity = ECS.createEntity({
                                Name = `{self.Model.Name}:{dropper.Name}:Reveal`,
                                Model = dropper,
                                Tycoon = self,
                        })
                end

                ECS.set(entity, "Reveal", {
                        item = dropper,
                        tycoon = self,
                        targets = targets,
                        duration = duration,
                        elapsed = 0,
                        onComplete = function()
                                if dropper:IsA("BasePart") then
                                        return
                                end

                                self:_ApplyUpgraderBonus(dropper)
                                self:_StartDropperLoop(dropper)
                        end,
                })
        end

	function Tycoon:_UnlockNextButtons(Config)
		for _, ButtonName in Config.Progression.Reveals do
			local NextButton = self.Buttons:FindFirstChild(ButtonName)
			if NextButton then
				self:_ButtonFadeIn(NextButton)
			end
		end
	end

	function Tycoon:_ButtonFadeIn(button)
		button.CanCollide = true
		button.CanTouch = true
		button.Transparency = 0

		local billboard = button:FindFirstChild("BillboardGui")
		if billboard then
			billboard.Enabled = true
		end

		local neon = button:FindFirstChild("Neon")

		TweenService:Create(
			button,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Transparency = 0 }
		):Play()

		if neon then
			TweenService:Create(
				neon,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Transparency = 0 }
			):Play()
		end
	end

	function Tycoon:_SetupUpgraders()
		self.ActiveDropperLoops = self.ActiveDropperLoops or {}
		self.AppliedUpgraders = self.AppliedUpgraders or {}
	end
end
