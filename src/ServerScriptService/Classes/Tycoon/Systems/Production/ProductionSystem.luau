--!strict
--[[
	@class ProductionSystem

	@desc
	Manages dropper production, visual effects, upgrader bonuses, and button fade-in animations.
	Coordinates with ECS Producer entities for production tick processing and Reveal components
	for build-item fade-in sequences.
]]

--// Constants

const DROPPER_VALUES: { [string]: number } = {
	GoldenDropper = 85,
	EliteDropper = 225,
}

const DEFAULT_DROPPER_VALUE = 15
const DEFAULT_PRODUCTION_INTERVAL = 2.5

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const TweenService = game:GetService("TweenService")
const CollectionService = game:GetService("CollectionService")
const TweenManager = require(ReplicatedStorage.Modules.TweenManager)

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
const Cleanup = require(script.Parent.Parent.Parent.Utilities.Cleanup)

--// Micro-Optimisations

const math_max = math.max
const math_clamp = math.clamp

--// Internal Utilities

local function GetNumericMultiplier(Player: Player): number
	return PlayerRuntimeState.GetMultiplier(Player)
end

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Public API

	function Tycoon:_SetupAmmoArea(Dropper: Instance)
		local LakesterModel = Dropper:FindFirstChild("Lakester")
		if not LakesterModel then
			return
		end

		self.CollisionManager.SetNonCollidable(LakesterModel, true)

		-- NPC animation is handled client-side via AnimationRegistry.
		-- Server only handles collision groups and visual state.

		for _, Descendant in LakesterModel:QueryDescendants("BasePart") do
			Descendant.Transparency = 0
		end

		for _, Descendant in Dropper:GetDescendants() do
			if not Descendant:IsA("BasePart") then
				continue
			end

			if Descendant:IsDescendantOf(LakesterModel) then
				continue
			end

			if Descendant.Name == "Requester" then
				Descendant.Transparency = 1
				Descendant.CanCollide = false
				continue
			end

			Descendant.CanCollide = true
			if Descendant.Name == "HumanoidRootPart" then
				Descendant.Transparency = 1
			end
		end
	end

	function Tycoon:_ApplyFadeStep(Descendant: Instance, Progress: number)
		if Descendant:IsA("Texture") then
			Descendant.Transparency = 0.45
		end
		
		if Descendant:IsA("Sound") then
			print("true")
			Descendant:Play()
		end

		if Descendant:IsA("ParticleEmitter") and not CollectionService:HasTag(Descendant, "SelfEnabling") then
			Descendant.Enabled = true
		end

		if Descendant:IsA("Decal") then
			Descendant.Transparency = 1 - Progress
		end

		if Descendant:IsA("BillboardGui") or Descendant:IsA("SurfaceGui") then
			Descendant.Enabled = true
		end

		if Descendant:IsA("ProximityPrompt") then
			if CollectionService:HasTag(Descendant, "SelfEnabling") then
				return true
			end

			Descendant.Enabled = true
		end

		if not Descendant:IsA("BasePart") then
			return true
		end

		if Descendant.Name == "HumanoidRootPart" then
			Descendant.Transparency = 1
			Descendant.CanCollide = false
			return true
		end

		if Descendant.Name == "Window" then
			Descendant.Transparency = 0.65
			Descendant.CanCollide = false
			return true
		end

		if CollectionService:HasTag(Descendant, "LowTransparency") then
			Descendant.Transparency = 0.65
			Descendant.CanCollide = true
			return true
		end

		if CollectionService:HasTag(Descendant, "Invisible") then
			Descendant.Transparency = 1
			Descendant.CanCollide = false
			return true
		end

		if Descendant.Parent.Name == "" then
			Descendant.Transparency = 0.2
			return true
		end

		Descendant.Transparency = 1 - Progress
		Descendant.CanCollide = not CollectionService:HasTag(Descendant, "NonCollidable")
		return true
	end

	function Tycoon:_GetDropperBaseValue(Dropper: Instance): number
		return DROPPER_VALUES[Dropper.Name] or DEFAULT_DROPPER_VALUE
	end

	function Tycoon:_CreateDropperVisual(Dropper: Instance, SpawnPart: BasePart)
		local Conveyor = self.MainItems:FindFirstChild("Conveyor1")
		if not Conveyor then
			return
		end

		local MovingPart = Conveyor:FindFirstChild("MovingPart")
		local Collector = Conveyor:FindFirstChild("Collector")
		if not MovingPart or not MovingPart:IsA("BasePart") then
			return
		end

		local Part = Instance.new("Part")
		Part.Name = "DropperVisual"
		Part.Size = Vector3.new(1, 1, 1)
		Part.Shape = Enum.PartType.Block
		Part.Material = Enum.Material.Neon
		Part.Anchored = true
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = false
		Part.CastShadow = false
		Part.CFrame = SpawnPart.CFrame
		Part.Parent = self.DropperVisualsFolder

		if Dropper.Name == "GoldenDropper" then
			Part.Color = BrickColor.new("Gold").Color
		elseif Dropper.Name == "EliteDropper" then
			Part.Color = BrickColor.new("Royal purple").Color
		else
			Part.Color = BrickColor.new("Lime green").Color
		end

		local ConveyorY = MovingPart.Position.Y + (MovingPart.Size.Y * 0.5) + (Part.Size.Y * 0.5)
		local DropTargetPosition = Vector3.new(SpawnPart.Position.X, ConveyorY, SpawnPart.Position.Z)
		local StartRotation = SpawnPart.CFrame - SpawnPart.Position
		local ConveyorDirection = MovingPart.CFrame.LookVector
		local TravelDistance = MovingPart.Size.Z * 0.5

		if Collector and Collector:IsA("BasePart") then
			local ToCollector = Collector.Position - DropTargetPosition
			local ProjectedDistance = ToCollector:Dot(ConveyorDirection)
			if ProjectedDistance > 0 then
				TravelDistance = ProjectedDistance
			end
		end

		local CollectorTargetPosition = DropTargetPosition + (ConveyorDirection * TravelDistance)
		local ConveyorTweenTime = math_max(TravelDistance / 23, 0.1)

		local DropTween = TweenService:Create(
			Part,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(DropTargetPosition) * StartRotation }
		)
		DropTween:Play()
		DropTween.Completed:Connect(function()
			if not Part.Parent then
				return
			end

			local ConveyorTween = TweenService:Create(
				Part,
				TweenInfo.new(ConveyorTweenTime, Enum.EasingStyle.Linear),
				{ CFrame = CFrame.new(CollectorTargetPosition) * StartRotation }
			)
			ConveyorTween:Play()
		end)

		Cleanup.destroyLater(Part, 0.35 + ConveyorTweenTime + 0.25)
	end

	function Tycoon:_ApplyUpgraderBonus(Dropper: Instance)
		if self.AppliedUpgraders[Dropper] then
			return
		end

		local Bonus = nil
		if Dropper.Name == "BasicUpgrader" then
			Bonus = 2
		elseif Dropper.Name == "EnchancedUpgrader" then
			Bonus = 3
		end

		if not Bonus then
			return
		end

		self.AppliedUpgraders[Dropper] = true

		local Owner = self.Owner
		if not Owner then
			return
		end

		local CurrentMultiplier = GetNumericMultiplier(Owner)
		if CurrentMultiplier == 1 then
			PlayerRuntimeState.SetMultiplier(Owner, CurrentMultiplier * Bonus)
		else
			PlayerRuntimeState.SetMultiplier(Owner, CurrentMultiplier + Bonus)
		end
	end

	function Tycoon:_StartDropperLoop(Dropper: Instance)
		local SpawnPart = Dropper:FindFirstChild("Spawn")
		if not SpawnPart or not SpawnPart:IsA("BasePart") then
			return
		end

		if self.ActiveDropperLoops[Dropper] then
			return
		end

		self.ActiveDropperLoops[Dropper] = ECS.createEntity({
			Name = `{self.Model.Name}:{Dropper.Name}:Producer`,
			Model = Dropper,
			Tycoon = self,
			Producer = {
				tycoon = self,
				dropper = Dropper,
				spawnPart = SpawnPart,
				value = self:_GetDropperBaseValue(Dropper),
				interval = DEFAULT_PRODUCTION_INTERVAL,
				elapsed = 0
			}
		})
	end

	function Tycoon:_StopAllDropperLoops()
		for _, Entity in self.ActiveDropperLoops do
			ECS.deleteEntity(Entity)
		end

		table.clear(self.ActiveDropperLoops)
	end

	function Tycoon:_StopAllMoneyDuplicatorLoops()
		if self.MoneyDuplicatorLoops then
			table.clear(self.MoneyDuplicatorLoops)
		end
	end

	function Tycoon:_FadeInComplete(Dropper: Instance, DurationOverride: number?, OnRevealComplete: (() -> ())?)
		local Duration = if DurationOverride ~= nil then DurationOverride else 1
		local Targets = { Dropper }

		if Dropper:IsA("Model") and Dropper.Name == "AmmoArea" then
			self:_SetupAmmoArea(Dropper)
		end

		for _, Descendant in Dropper:GetDescendants() do
			table.insert(Targets, Descendant)
		end

		local Entity = self.ItemEntities and self.ItemEntities[Dropper]
		if not Entity then
			Entity = ECS.createEntity({
				Name = `{self.Model.Name}:{Dropper.Name}:Reveal`,
				Model = Dropper,
				Tycoon = self
			})
		end

		ECS.set(Entity, "Reveal", {
			item = Dropper,
			tycoon = self,
			targets = Targets,
			duration = Duration,
			elapsed = 0,
			onComplete = function()
				-- Runs AFTER the final _ApplyFadeStep pass, so any config
				-- properties (Transparency, CanCollide, etc.) re-applied here
				-- are the authoritative final state and are not clobbered.
				if OnRevealComplete then
					OnRevealComplete()
				end

				if Dropper:IsA("BasePart") then
					return
				end

				self:_ApplyUpgraderBonus(Dropper)
				self:_StartDropperLoop(Dropper)

				-- Start MoneyDuplicator energy bar loop
				if string.sub(Dropper.Name, 1, 15) == "MoneyDuplicator" then
					self:MoneyDuplicator(Dropper)
				end
			end
		})
	end

	function Tycoon:_UnlockNextButtons(Config: any)
		for _, ButtonName in Config.Progression.Reveals do
			local NextButton = self.Buttons:FindFirstChild(ButtonName)
			if NextButton then
				self:_ButtonFadeIn(NextButton)
			end
		end
	end

	function Tycoon:_ButtonFadeIn(Button: BasePart)
		Button.CanCollide = true
		Button.CanTouch = true
		Button.Transparency = 0

		local Billboard = Button:FindFirstChild("BillboardGui") :: BillboardGui
		if Billboard then
			Billboard.Enabled = true
		end

		local Neon = Button:FindFirstChild("Neon")

		TweenService:Create(Button, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0 }):Play()

		if Neon then
			TweenService:Create(Neon, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0 }):Play()
		end
	end
	
	local function CalculateTargetSize(object : BasePart, x : number, y : number, z : number): (Vector3, CFrame)
		local targetSize = object.Size + Vector3.new(x, y, z)
		local targetCFrame = object.CFrame * CFrame.new(-x / 2, y, z)
		return targetSize, targetCFrame
	end

	type MoneyDuplicator = {
		EnergyBar : BasePart
	}

	function Tycoon:MoneyDuplicator(Object : Instance & MoneyDuplicator, Duration :number?)
		const EnergyBar = Object.EnergyBar

		-- Prevent overlapping cycles
		if self.MoneyDuplicatorLoops[Object] then
			return
		end

		self.MoneyDuplicatorLoops[Object] = true

		local originalSize = EnergyBar.Size
		local originalCFrame = EnergyBar.CFrame
		local upDuration = Duration or 12.5
		local downDuration = 3

		local upTargetSize, upTargetCFrame = CalculateTargetSize(EnergyBar, 18.16, 0, 0)

		-- Color gradient: red -> terra cotta -> amber -> yellow -> green
		local colorStops = {
			Color3.fromRGB(255, 0, 0),
			Color3.fromRGB(226, 114, 91),
			Color3.fromRGB(255, 191, 0),
			Color3.fromRGB(255, 255, 0),
			Color3.fromRGB(0, 255, 0),
		}

		local function lerpColor(t: number): Color3
			local segments = #colorStops - 1
			local scaled = t * segments
			local index = math.floor(scaled)
			if index >= segments then
				return colorStops[#colorStops]
			end
			local frac = scaled - index
			return colorStops[index + 1]:Lerp(colorStops[index + 2], frac)
		end

		local function runCycle()
			if not EnergyBar.Parent or not self.MoneyDuplicatorLoops[Object] then
				return
			end

			-- Reset to bottom state at start of each cycle
			EnergyBar.Size = originalSize
			EnergyBar.CFrame = originalCFrame
			EnergyBar.Color = colorStops[1]

			-- Track fill progress for color interpolation
			local progressValue = Instance.new("NumberValue")
			progressValue.Value = 0

			local colorConn = progressValue.Changed:Connect(function(value)
				if EnergyBar.Parent and self.MoneyDuplicatorLoops[Object] then
					EnergyBar.Color = lerpColor(value)
				end
			end)

			-- Up tween: grow the energy bar upward over 12.5 seconds (linear)
			local sizeTween = TweenService:Create(EnergyBar,
				TweenInfo.new(upDuration, Enum.EasingStyle.Linear),
				{ Size = upTargetSize, CFrame = upTargetCFrame }
			)

			local colorTween = TweenService:Create(progressValue,
				TweenInfo.new(upDuration, Enum.EasingStyle.Linear),
				{ Value = 1 }
			)


			sizeTween:Play()
			colorTween:Play()

			sizeTween.Completed:Once(function()
				colorConn:Disconnect()
				progressValue:Destroy()

				if not EnergyBar.Parent or not self.MoneyDuplicatorLoops[Object] then
					return
				end

				-- Award 2500 cash when the energy bar is completely full
				self:_AddCollectorAmount(2500)

				-- Down tween: shrink back to original over 3 seconds (linear)
				local downTween = TweenService:Create(EnergyBar,
					TweenInfo.new(downDuration, Enum.EasingStyle.Linear),
					{ Size = originalSize, CFrame = originalCFrame, Color = colorStops[1] }
				)
				downTween:Play()

				downTween.Completed:Once(function()
					if not EnergyBar.Parent or not self.MoneyDuplicatorLoops[Object] then
						return
					end

				-- Schedule next cycle
				task.spawn(runCycle)
				end)
			end)
		end

		runCycle()
	end

	--// Internal Methods

	function Tycoon:_SetupUpgraders()
		self.ActiveDropperLoops = self.ActiveDropperLoops or {}
		self.AppliedUpgraders = self.AppliedUpgraders or {}
		self.MoneyDuplicatorLoops = self.MoneyDuplicatorLoops or {}
	end
end
