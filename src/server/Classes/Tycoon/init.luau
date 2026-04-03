
-- Developed by Sacredbow1

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ReturnRequest = ReplicatedStorage.Remotes:FindFirstChild("ReturnRequest")
local PhysicsService = game:GetService("PhysicsService")
local GamePackage = ReplicatedStorage:WaitForChild("GamePackage")
local ServerScriptService = game:GetService("ServerScriptService")



local RocketSystem = require(ServerScriptService.Classes.Tycoon.Systems.Rocket)
local TweenManager =  require(ReplicatedStorage.Modules.TweenManager) :: ModuleScript
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local ReloadConfiguation = require(script.Systems.ReloadConfig)
local ColorConfiguration = require(script.Configuration.ColorConfiguration)
local BuildSystem = require(script.Systems.BuildSystem)
local CollectorSystem = require(script.Systems.CollectorSystem)
local ProductionSystem = require(script.Systems.ProductionSystem)
local ElectricitySystem = require(script.Systems.ElectricitySystem)

local VisualEffects = GamePackage["Visual Effects"]


local Tycoon = {}
Tycoon.__index = Tycoon

BuildSystem(Tycoon)
CollectorSystem(Tycoon, {
	ProfileManager = ProfileManager,
})
ProductionSystem(Tycoon, {
	TweenService = TweenService,
	CollectionService = CollectionService,
	Debris = Debris,
})
ElectricitySystem(Tycoon, {
	Players = Players,
	Debris = Debris,
	CollectionService = CollectionService,
	ReplicatedStorage = ReplicatedStorage,
	ReturnRequest = ReturnRequest,
})


function Tycoon.new(tycoonModel, playerService, purchaseService, ragdollModule, collisionManager)
	
	local self = setmetatable({}, Tycoon)

	
	self.Model = tycoonModel
	self.PlayerService = playerService
	self.PurchaseService = purchaseService
	self.RagdollModule = ragdollModule
	self.CollisionManager = collisionManager
	collisionManager.Initialize()

	
	self.MainItems = tycoonModel:WaitForChild("MainItems")
	self.Values = tycoonModel:WaitForChild("Values")
	self.Stages = tycoonModel:WaitForChild("Stages")
	self.Buttons = tycoonModel:WaitForChild("Buttons")
	self.PurchasedItems = tycoonModel:WaitForChild("PurchasedItems")
	self.Droppers = tycoonModel:WaitForChild("Droppers")
	self.GunModels = tycoonModel:WaitForChild("GunModels")
	self.Components = tycoonModel:FindFirstChild("Components")
	self.Audios = tycoonModel:FindFirstChild("Audios")
	self.DropperVisualsFolder = tycoonModel:FindFirstChild("DropperVisuals")
	if not self.DropperVisualsFolder then
		self.DropperVisualsFolder = Instance.new("Folder")
		self.DropperVisualsFolder.Name = "DropperVisuals"
		self.DropperVisualsFolder.Parent = tycoonModel
	end


	self.OwnerValue = self.Values:FindFirstChild("OwnerValue")
	if not self.OwnerValue then
		self.OwnerValue = Instance.new("ObjectValue")
		self.OwnerValue.Name = "OwnerValue"
		self.OwnerValue.Parent = self.Values
	end

	self.ATM = self.MainItems:WaitForChild("ATM")
	self.CollectorAmount = 0


	self.x2Upgraders = {}
	self.x3Upgraders = {}
	self.MovedItems = {}
	self.ActiveDropperLoops = {}
	self.AppliedUpgraders = {}


	
	self.ArmourVest1 = GamePackage.CharacterItems.Armour.Armour1
	self.ArmourVest2 = GamePackage.CharacterItems.Armour.Armour2
	self.NPC_IdleAnimation = GamePackage:WaitForChild("Animations").NPC_Idle
	
	self.Activation = GamePackage["Visual Effects"].Activation
	self.VisualEffects = VisualEffects
	self.Rocket = self.Components.Rocket

	self.IsSetup = false





	self.ButtonTemplate  = self.Buttons:Clone() 
	self.ButtonTemplate.Parent = nil

    self.CompletedTycoon = false :: boolean
	

	return self
end







function Tycoon:Init()
	if self.IsSetup then return end
	self.IsSetup = true

     warn("Initializing...:", self.Model.Name)
	
	
	self:_BuildTemplateCache()
	self:_ApplyStageColors()
	self:_SetupDoor()
	self:_SetupButtons()
	self:_SetupCollector()
	self:_SetupUpgraders()
	self:_SetupElectricity()
	self:_SetupLasers()
	self:_SetupGate()
	self:_SetupArmour()
	self:_SetupGuns()
	self:SetupCollsion()
	--self:_SetupGamepassTextAnimation()
	self:_SetupLabDoors()
	self:_SetupProximityPrompts()
	self:ReloadConfiguration()
	
end

function Tycoon:_ApplyStageColors()
	local palette = ColorConfiguration.White
	if not palette then
		return
	end

	for _, descendant in ipairs(self.Stages:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if CollectionService:HasTag(descendant, "Primary") then
				descendant.Color = palette.Primary
			elseif CollectionService:HasTag(descendant, "Secondary") then
				descendant.Color = palette.Secondary
			elseif CollectionService:HasTag(descendant, "Accent") then
				descendant.Color = palette.Accent
			end
		end
	end
end





local existingGroups = PhysicsService:GetRegisteredCollisionGroups()
local function collisionGroupExists(name)
	for _, group in ipairs(existingGroups) do
		if group.name == name then
			return true
		end
	end
	return false
end

if not collisionGroupExists("Players") then
	PhysicsService:RegisterCollisionGroup("Players")
end
function Tycoon:_SetupDoor()
	local door = self.MainItems.OwnerDoor:WaitForChild("Door")


	door.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		local hasTycoon = player:FindFirstChild("hasTycoon")
		if not hasTycoon or hasTycoon.Value then return end

		if not self.OwnerValue.Value then
			self:_ClaimTycoon(player)
		end
	end)
end


function Tycoon:_ClaimTycoon(player)
	print("Claimed by:", player.Name)

	self.OwnerValue.Value = player
	player.hasTycoon.Value = true

	self.PlayerService:RegisterPlayerTycoon(player, self)

	local door = self.MainItems.OwnerDoor.Door
	local titleLabel = self.MainItems.OwnerDoor.Title.SurfaceGui.TextLabel
	titleLabel.Text = player.Name .. "'s Tycoon"
	door.Transparency = 0.6

	self:_AssignTeam(player)

	local spawn = self.MainItems:FindFirstChild("TycoonSpawn")
	if spawn then
	
		self.CharacterAddedConn = player.CharacterAdded:Connect(function(char)
			char:PivotTo(spawn.CFrame)
		end)
	end

	self.PurchaseService:OnTycoonClaimed(player, self)
end

function Tycoon:_AssignTeam(player)
	local Teams = game:GetService("Teams")
	local teamMap = {
		Tycoon1 = "Destroyer",
		Tycoon2 = "Alpha",
		Tycoon3 = "Inferno",
		Tycoon4 = "Warrior",
		Tycoon5 = "Violent",
		Tycoon6 = "Vengeance",
		Tycoon7 = "Powerhouse"
	}

	local teamName = teamMap[self.Model.Name]
	if teamName then
		player.Team = Teams:FindFirstChild(teamName)
	end
end


function Tycoon:_SetupButtons()
	for _, button in ipairs(self.Buttons:GetChildren()) do
		if button:IsA("BasePart") then
			self:_SetupButton(button)
		end
	end
end


function Tycoon:_SetupButton(button)
	local price = button:FindFirstChild("Price")
	local gamepass = button:FindFirstChild("Gamepass")
	


	

	if not price and not gamepass then
	return
end


	if button.Transparency == 1 then
		button.CanCollide = false
		local billboard = button:FindFirstChild("BillboardGui")
		if billboard then billboard.Enabled = false end
	end

	button.Touched:Connect(function(hit)
		if button.Transparency == 1 then return end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or self.OwnerValue.Value ~= player then
			
			return 
		end

		self:_ProcessButtonPurchase(player, button)
	end)
end


function Tycoon:_ProcessButtonPurchase(player, button)
	local ButtonType = button:FindFirstChild("Type")
if not ButtonType then
	warn("Button missing Type:", button:GetFullName())
	return
end


  local profile = ProfileManager.Profiles[player]

	if not self:_CheckDependencies(button) then
		warn("Dependencies not met for:", button.Name)
		return
	end


		local price = button:FindFirstChild("Price")
	local gamepass = button:FindFirstChild("Gamepass")

		if  ButtonType.Value == "Rebirth" then
			local Rebirths = profile.Data.Rebirths
			if Rebirths >= price.Value then

	local ActivationClone = self.Activation:Clone()
	ActivationClone.Parent = self.MainItems
	local ParticleEmitter : ParticleEmitter = ActivationClone.Activation1

ActivationClone.CFrame = button.CFrame * CFrame.new(0, 1.65, 0)


		button:Destroy()
	ParticleEmitter:Emit(1)

	task.delay(3, function()
				ActivationClone:Destroy()
	end)
				
		
		else
			ReturnRequest:FireClient(self.OwnerValue.Value, "Not Enough Rebirths")

	return
end
		
end



	if gamepass then
		self.PurchaseService:PromptGamepass(player, button, self)
		return
	end

	
	
	
	if price then
		local cash = profile.Data.Cash
		if cash >= price.Value then
			
			ProfileManager.AddCash(player, -price.Value)
			self:_SpawnButtonItems(button)
			self:_UnlockNextButtons(button)
			local ActivationClone = self.Activation:Clone()
			ActivationClone.Parent = self.MainItems
			local ParticleEmitter : ParticleEmitter = ActivationClone.Activation1

ActivationClone.CFrame = button.CFrame * CFrame.new(0, 1.65, 0)


			button:Destroy()
	ParticleEmitter:Emit(1)
		
			task.delay(3, function()
				ActivationClone:Destroy()
			end)
			
			
		else
			ReturnRequest:FireClient(self.OwnerValue.Value, "Not Enough Cash")

		end
	end
end





function Tycoon:SetupCollsion()
	local Armour1 = self.Stages.Stage1.Armour1:FindFirstChild("")
	local Armour2  = self.Stages.Stage1.Armour2:FindFirstChild("")
	
	
	local ammoArea = self.Stages.Stage1:FindFirstChild("AmmoArea")
	if ammoArea then
		local lakester = ammoArea:FindFirstChild("Lakester")
		if lakester then
			
			self.CollisionManager.NonCollidable(lakester, false)
			self.CollisionManager.NonCollidable(Armour1, false)
			self.CollisionManager.NonCollidable(Armour2, false)
			
		end
	end
end



function Tycoon:ReloadConfiguration()
	if self.ReloadConfigurationConnected then
		return
	end

	local ammoArea = self.Stages.Stage1:FindFirstChild("AmmoArea")
	if ammoArea then
		local lakester = ammoArea:FindFirstChild("Lakester")
		if lakester then
local Requester : BasePart = lakester:WaitForChild("Requester")
local ProximityPrompt =  Requester:FindFirstChild("ProximityPrompt")

ProximityPrompt.Triggered:Connect(ReloadConfiguation.onPromptTriggered)
			self.ReloadConfigurationConnected = true

		end
	end
		
end


function Tycoon:Cleanup()
	local previousOwner = self.OwnerValue.Value

	local door = self.MainItems.OwnerDoor.Door
	local titleLabel = self.MainItems.OwnerDoor.Title.SurfaceGui.TextLabel
	titleLabel.Text = "Unclaimed Tycoon"
	door.Transparency = 0.25
	
	self.ATM.Display.SurfaceGui.Money.Text = "0"
	self.CollectorAmount = 0
	self:_QueueCollectorDisplayUpdate(true)

	if self.Buttons then
		self.Buttons:Destroy()

		self.Buttons = self.ButtonTemplate:Clone()
		self.Buttons.Parent = self.Model

		self:_SetupButtons()
	end

	self:_StopAllDropperLoops()

	self:_RestoreMovedItems()

	for _, item in ipairs(self.PurchasedItems:GetChildren()) do
		item:Destroy()
	end

	for _, visual in ipairs(self.DropperVisualsFolder:GetChildren()) do
		visual:Destroy()
	end

	self.x2Upgraders = {}
	self.x3Upgraders = {}
	self.AppliedUpgraders = {}

	local stage4 = self.Stages:FindFirstChild("Stage4")
	if stage4 then
		local fences = stage4:FindFirstChild("Fences")
		if fences then
			local lever = fences:FindFirstChild("Leaver")
			if lever and lever:FindFirstChild("Prompt") then
				local prompt = lever.Prompt:FindFirstChild("ProximityPrompt")
				if prompt then prompt.ActionText = "Open Gate" end
			end
		end
	end

	local buttonStand = self.Components and self.Components:FindFirstChild("ButtonStand")
	if buttonStand and buttonStand:FindFirstChild("Button") then
		buttonStand.Button.BrickColor = BrickColor.new("Bright green")
	end

	if previousOwner then
		local hasTycoon = previousOwner:FindFirstChild("hasTycoon")
		if hasTycoon then
			hasTycoon.Value = false
		end

		previousOwner:SetAttribute("Multiplier", 1)
		previousOwner:SetAttribute("Power", false)
		previousOwner:SetAttribute("ArmourEquipped", false)
	end


	self.OwnerValue.Value = nil


	if self.CharacterAddedConn then
		self.CharacterAddedConn:Disconnect()
		self.CharacterAddedConn = nil
	end

	warn(`Cleanup complete: {self.Model.Name}`)
end



function Tycoon:_SetupLabDoors()
	local ScientificLab = self.Stages.Stage2:FindFirstChild("ScientificLab")
	local Door = ScientificLab.LabDoor
	local Magnitude = Door.Magnitude
	local Magnitude2 = Door.Magnitude2
	local _IsOpen = false
	local Debounce = false

	local function handleDoorTrigger()
		if Debounce then return end
		if Door.BaseDoor.Transparency == 1 then return end
		if not self.OwnerValue.Value then return end

		Debounce = true

	
		local openTarget = Door.PrimaryPart.CFrame * CFrame.new(13.5, 0, 0)
		TweenManager.Model(Door, openTarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
		_IsOpen = true

		task.wait(4)


		local closeTarget = Door.PrimaryPart.CFrame * CFrame.new(-13.5, 0, 0)
		TweenManager.Model(Door, closeTarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
		_IsOpen = false

		task.wait(2)


		local owner = self.OwnerValue.Value
		if owner then
			local function isPlayerInBox(boxPart)
				local params = OverlapParams.new()
				params.FilterDescendantsInstances = {owner.Character}
				params.FilterType = Enum.RaycastFilterType.Include
				local parts = workspace:GetPartBoundsInBox(
					boxPart.CFrame,
					boxPart.Size,
					params
				)
				return #parts > 0
			end

			if isPlayerInBox(Magnitude) or isPlayerInBox(Magnitude2) then
				local reopenTarget = Door.PrimaryPart.CFrame * CFrame.new(13.5, 0, 0)
				TweenManager.Model(Door, reopenTarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
				_IsOpen = true
				task.wait(4)
				local recloseTarget = Door.PrimaryPart.CFrame * CFrame.new(-13.5, 0, 0)
				TweenManager.Model(Door, recloseTarget, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
				_IsOpen = false
			end
		end

		task.wait(2)
		Debounce = false
	end

	local function onTouched(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= self.OwnerValue.Value then return end
		handleDoorTrigger()
	end

	Magnitude.Touched:Connect(onTouched)
	Magnitude2.Touched:Connect(onTouched)
end
function Tycoon:_SetupProximityPrompts()
	local Debounce = false
	
local ButtonStand  = self.Components.ButtonStand
local ActivateNuke : ProximityPrompt = ButtonStand.Button:FindFirstChild("Activate")

ActivateNuke.Triggered:Connect(function(player)
	if Debounce then 
		return
	end
if self.OwnerValue.Value == player then
			local Rocket = RocketSystem.new(self.Rocket, player, self.PlayerService, self.Audios.NuclearAudios)
			self.PlayerService:ActivateRocket(player, true)
			Rocket:Init()
			Debounce = true
			ButtonStand.Button.BrickColor = BrickColor.new("Really red")
			self.PlayerService:ActivateRocket(player, false)
			task.wait(1200) -- Time wait for the next nuke
			Debounce = false
			ButtonStand.Button.BrickColor = BrickColor.new("Bright green")
   end
	
end)

end

function Tycoon:_SetupLasers()
	local lasers = self.Stages.Stage4.Lasers
	for _, laser in ipairs(lasers:GetChildren()) do
		laser.Touched:Connect(function(hit)
			if laser.Transparency ~= 0 then return end

			local player = Players:GetPlayerFromCharacter(hit.Parent)
			
			if player then
				if self.OwnerValue.Value == player then
					return 
				end
				
				local Character = player.Character or player.CharacterAdded:Wait()
				local hum : Humanoid = Character:FindFirstChild("Humanoid")
				
				if hum then
					hum:TakeDamage(100)
				end
			end
	
		end)
	end
end


function Tycoon:_SetupGate()
	local gate = self.Stages.Stage4.Fences.Gate
	local lever = self.Stages.Stage4.Fences.Leaver
	local prompt = lever.Prompt.ProximityPrompt

	local isOpen = false
	local debounce = false

	prompt.Triggered:Connect(function()
		if debounce then return end
		debounce = true
		prompt.Enabled = false

		local startGate = gate:GetPivot()
		local startLever = lever:GetPivot()
		local targetGate = isOpen and startGate * CFrame.new(-45, 0, 0) or startGate * CFrame.new(45, 0, 0)
		local targetLever = isOpen and startLever * CFrame.Angles(math.rad(90), 0, 0) or startLever * CFrame.Angles(math.rad(-90), 0, 0)


		task.spawn(function()
			local duration = 2
			local elapsed = 0
			while elapsed < duration do
				local dt = task.wait()
				elapsed = math.min(elapsed + dt, duration)
				local alpha = elapsed / duration
				gate:PivotTo(startGate:Lerp(targetGate, alpha))
				lever:PivotTo(startLever:Lerp(targetLever, alpha))
			end
		end)

		isOpen = not isOpen
		prompt.ActionText = isOpen and "Close Gate" or "Open Gate"

		task.wait(4)
		debounce = false
		prompt.Enabled = true
	end)
end


function Tycoon:_SetupArmour()
	local armour1 = self.Stages.Stage1.Armour1
	local armour2 = self.Stages.Stage1.Armour2
	
	local ArmourVest1 = ReplicatedStorage.GamePackage.CharacterItems.Armour.Armour1:Clone()
	local ArmourVest2 = ReplicatedStorage.GamePackage.CharacterItems.Armour.Armour2:Clone()
	
	
	armour1.Part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= self.OwnerValue.Value then return end
		if armour1.Part.Transparency ~= 0 then return end
		if player:GetAttribute("ArmourEquipped") then return end

		local char = player.Character
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.MaxHealth += 50
			hum.Health += 50
		end

		player:SetAttribute("ArmourEquipped", true)
		local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		if torso then
			ArmourVest1.Parent = char
			local offset = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0)
			ArmourVest1:SetPrimaryPartCFrame(torso.CFrame * offset)
			local newWeld = Instance.new("WeldConstraint")
			newWeld.Part0 = torso
			newWeld.Part1 = ArmourVest1.Primary
			newWeld.Parent = ArmourVest1.Primary
		end
		
	end)

	
	armour2.Part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player ~= self.OwnerValue.Value then return end
		if armour2.Part.Transparency ~= 0 then return end
		if player:GetAttribute("ArmourEquipped") then return end

		local char = player.Character
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.MaxHealth += 120
			hum.Health += 120
		end

		player:SetAttribute("ArmourEquipped", true)
	
	
		local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		if torso then
			ArmourVest2.Parent = char
			local offset = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0)
			ArmourVest2:SetPrimaryPartCFrame(torso.CFrame * offset)
			local newWeld = Instance.new("WeldConstraint")
			newWeld.Part0 = torso
			newWeld.Part1 = ArmourVest2.Primary
			newWeld.Parent = ArmourVest2.Primary
		end


	end)
end


function Tycoon:_SetupGuns()
	for _, gunModel in ipairs(self.GunModels:GetChildren()) do
		local ProximityPrompt : ProximityPrompt = gunModel.Requester.ProximityPrompt
		ProximityPrompt.Triggered:Connect(function(player : Player)
			if player ~= self.OwnerValue.Value then return end
			local GunName = gunModel.Name
			local Character = player.Character
			if player.Backpack:FindFirstChild(GunName) 
				or player.StarterGear:FindFirstChild(GunName) 
				or (Character and Character:FindFirstChild(GunName)) then
				return
			end

			--if not self.GunModels:FindFirstChild(GunName) then
			--	return
			--end
			local Gun = ServerStorage.Guns:FindFirstChild(GunName)
			if Gun then 
				local GunClone = Gun:Clone()
				GunClone.Parent = player.Backpack
			end
		end)
	end
end


function Tycoon:CheckCompletion(buttonFolder)
	for _, button in buttonFolder:GetChildren() do
		local buttonType = button:FindFirstChild("Type")
		if buttonType and buttonType.Value == "Basic" then
			self.CompletedTycoon = false
			return false
		end
	end

	self.CompletedTycoon = true
	
	return true
end



--function Tycoon:_SetupGamepassTextAnimation()
--	local gamepassItems = self.MainItems:FindFirstChild("GamepassItems")
--	if not gamepassItems then return end

--	for _, item in ipairs(gamepassItems:GetChildren()) do
--		local billboard = item:FindFirstChild("BillboardGui")
--		if billboard then
--			local textLabel = billboard:FindFirstChild("TextLabel")
--			if textLabel then
			
--				TweenService:Create(
--					textLabel,
--					TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
--					{Position = textLabel.Position + UDim2.new(0, 0, 0.05, 0)}
--				):Play()
--			end
--		end
--	end
--end

return Tycoon
