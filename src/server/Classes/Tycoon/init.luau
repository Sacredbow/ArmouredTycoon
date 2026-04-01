
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

local VisualEffects = GamePackage["Visual Effects"]


local Tycoon = {}
Tycoon.__index = Tycoon


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
	self.DropperPartsFolder = tycoonModel:FindFirstChild("DropperParts")
	self.Components = tycoonModel:FindFirstChild("Components")
	self.Audios = tycoonModel:FindFirstChild("Audios")


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


	
	self.ArmourVest1 = GamePackage.CharacterItems.Armour.Armour1
	self.ArmourVest2 = GamePackage.CharacterItems.Armour.Armour2
	self.NPC_IdleAnimation = GamePackage:WaitForChild("Animations").NPC_Idle
	
	self.Activation = GamePackage["Visual Effects"].Activation
	self.Rocket = self.Components.Rocket

	self.IsSetup = false





	self.ButtonTemplate  = self.Buttons:Clone() 
	self.ButtonTemplate.Parent = nil

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
if not collisionGroupExists("DropperParts") then
	PhysicsService:RegisterCollisionGroup("DropperParts")
end
PhysicsService:CollisionGroupSetCollidable("DropperParts", "Players", false)
PhysicsService:CollisionGroupSetCollidable("DropperParts", "Default", true)
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

	if not price and not gamepass then return end


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
	


	if not self:_CheckDependencies(button) then
		warn("Dependencies not met for:", button.Name)
		return
	end

	local price = button:FindFirstChild("Price")
	local gamepass = button:FindFirstChild("Gamepass")

	if gamepass then
		self.PurchaseService:PromptGamepass(player, button, self)
		return
	end

	local profile = ProfileManager.Profiles[player]
	
	
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


function Tycoon:_BuildTemplateCache()
	self.TemplateCache = {}

	for _, obj in ipairs(self.Model:GetDescendants()) do
		self.TemplateCache[obj.Name] = obj
	end
end


function Tycoon:_CheckDependencies(button)
	local dependenciesFolder = button:FindFirstChild("Dependencies")
	local singleDep = button:FindFirstChild("Dependency")

	local required = {}

	if dependenciesFolder then
		for _, dep in ipairs(dependenciesFolder:GetChildren()) do
			if dep:IsA("StringValue") then
				table.insert(required, dep.Value)
			end
		end
	elseif singleDep then
		table.insert(required, singleDep.Value)
	end


	for _, itemName in ipairs(required) do
		local found = self.TemplateCache[itemName]

		if not found then
			return false
		end
	end

	return true
end


function Tycoon:_SpawnButtonItems(button)
	local dependenciesFolder = button:FindFirstChild("Dependencies")
	local singleDep = button:FindFirstChild("Dependency")

	local items = {}

	if dependenciesFolder then
		for _, dep in ipairs(dependenciesFolder:GetChildren()) do
			if dep:IsA("StringValue") then
				table.insert(items, dep.Value)
			end
		end
	elseif singleDep then
		table.insert(items, singleDep.Value)
	end

	
	for _, itemName in ipairs(items) do
		local template = self:_FindTemplate(itemName)
		if template then
			self:_SpawnItem(template)
		else
			print(" Template not found:", itemName)
		end
	end
end


function Tycoon:_FindTemplate(itemName)
	
	local template = self.Droppers:FindFirstChild(itemName)
	if template then
		 return template
	 end

	
	template = self.GunModels:FindFirstChild(itemName)
	if template then 
	
		local light = template:FindFirstChild("Light")
		if light and light:FindFirstChild("Light") and light.Light:FindFirstChild("Light") then
			local pointLight = light.Light.Light:FindFirstChild("PointLight")
			if pointLight then
				pointLight.Brightness = 1
			end
		end
		return template 
	end

	
	local gamepassFolder = self.MainItems:FindFirstChild("GamepassItems")
	if gamepassFolder then
		template = gamepassFolder:FindFirstChild(itemName)
		if template then return template end
	end

	
	for _, stage in ipairs(self.Stages:GetChildren()) do
		template = stage:FindFirstChild(itemName, true)
		if template then return template end
	end
	
	if self.Components then
		template = self.Components:FindFirstChild(itemName, true)
		if template then return template end
	end
	return nil
end


function Tycoon:_SpawnItem(item)
	if not item then return end

	self:_CacheMovedItem(item)
	item.Parent = self.PurchasedItems

	
	task.spawn(function()
		self:_FadeInComplete(item)
	end)
end

function Tycoon:_CacheMovedItem(item)
	if self.MovedItems[item] then
		return
	end

	self.MovedItems[item] = {
		Parent = item.Parent,
		Template = item:Clone(),
	}

	self.MovedItems[item].Template.Parent = nil
end

function Tycoon:_RestoreItemFromTemplate(item, template)
	if item:IsA("Model") and template:IsA("Model") then
		item:PivotTo(template:GetPivot())
	elseif item:IsA("BasePart") and template:IsA("BasePart") then
		item.CFrame = template.CFrame
	end

	if item:IsA("BasePart") and template:IsA("BasePart") then
		item.Transparency = template.Transparency
		item.CanCollide = template.CanCollide
		item.Material = template.Material
		item.Color = template.Color
	elseif item:IsA("Decal") and template:IsA("Decal") then
		item.Transparency = template.Transparency
	elseif item:IsA("Texture") and template:IsA("Texture") then
		item.Transparency = template.Transparency
	elseif item:IsA("BillboardGui") and template:IsA("BillboardGui") then
		item.Enabled = template.Enabled
	elseif item:IsA("SurfaceGui") and template:IsA("SurfaceGui") then
		item.Enabled = template.Enabled
	elseif item:IsA("ProximityPrompt") and template:IsA("ProximityPrompt") then
		item.Enabled = template.Enabled
		item.ActionText = template.ActionText
	elseif item:IsA("ParticleEmitter") and template:IsA("ParticleEmitter") then
		item.Enabled = template.Enabled
	elseif item:IsA("PointLight") and template:IsA("PointLight") then
		item.Brightness = template.Brightness
	end

	local itemChildren = item:GetChildren()
	local templateChildren = template:GetChildren()
	for index, templateChild in ipairs(templateChildren) do
		local itemChild = itemChildren[index]
		if (not itemChild or itemChild.Name ~= templateChild.Name or itemChild.ClassName ~= templateChild.ClassName) then
			itemChild = item:FindFirstChild(templateChild.Name)
		end

		if itemChild and itemChild.ClassName == templateChild.ClassName then
			self:_RestoreItemFromTemplate(itemChild, templateChild)
		end
	end
end

function Tycoon:_RestoreMovedItems()
	local movedItems = {}
	for item, restoreData in self.MovedItems do
		table.insert(movedItems, {Item = item, RestoreData = restoreData})
	end

	for _, entry in ipairs(movedItems) do
		local item = entry.Item
		local restoreData = entry.RestoreData

		if item and item.Parent then
			self:_RestoreItemFromTemplate(item, restoreData.Template)
			item.Parent = restoreData.Parent
		end

		restoreData.Template:Destroy()
		self.MovedItems[item] = nil
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
	local ammoArea = self.Stages.Stage1:FindFirstChild("AmmoArea")
	if ammoArea then
		local lakester = ammoArea:FindFirstChild("Lakester")
		if lakester then
warn("Found Lakester")
local Requester : BasePart = lakester:WaitForChild("Requester")
local ProximityPrompt =  Requester:FindFirstChild("ProximityPrompt")

ProximityPrompt.Triggered:Connect(ReloadConfiguation.onPromptTriggered)

		end
	end
		
end

function Tycoon:_FadeInComplete(dropper)
	local duration = 1
	local steps = 10
	local st = duration / steps


	if dropper.Name == "AmmoArea" and dropper:IsA("Model") then
		local lakesterModel = dropper:FindFirstChild("Lakester")
		if lakesterModel then
			
			self.CollisionManager.NonCollidable(lakesterModel, true)
			

			
			local humanoid = lakesterModel:FindFirstChild("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
				local track = animator:LoadAnimation(self.NPC_IdleAnimation)
				track.Looped = true
				track:Play()
			end

			
			for _, part in ipairs(lakesterModel:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
					part.Transparency = 0
				end
			end
		end


		
		for _, part in pairs(dropper:GetDescendants()) do
			if part:IsA("BasePart") then
			
				if lakesterModel and part:IsDescendantOf(lakesterModel) then
					continue
				end

				if part.Name == "Requester" then
					part.Transparency = 1
					part.CanCollide = false
					continue
				end

				part.CanCollide = true
				if part.Name == "HumanoidRootPart" then
					part.Transparency = 1
				end
			end
		end
	end

	
	if dropper:IsA("BasePart") or dropper:IsA("UnionOperation") then
		for _, v in dropper:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				if not CollectionService:HasTag(v, "Power") then
					v.Enabled = true
				end
			end
		end

		if CollectionService:HasTag(dropper, "LowTransparency") then
			dropper.Transparency = 0.65
			dropper.CanCollide = true
			return
		end

		if dropper.Name ~= "Window" then
			dropper.CanCollide = true
		else
			dropper.CanCollide = false
		end

		for i = 1, steps do
			local progress = i / steps
			dropper.Transparency = 1 - progress
			task.wait(st)
		end
		return
	end


	for i = 1, steps do
		local progress = i / steps

		for _, v in ipairs(dropper:GetDescendants()) do
			if v:IsA("Texture") then
				v.Transparency = 0.45
			end
			
			if v.Name == "HumanoidRootPart" then
				v.Transparency = 0.9
				continue
			end

			if v:IsA("Decal") then
				v.Transparency = 1 - progress
			end

			if v.Name == "Window" then
				v.Transparency = 0.65
				v.CanCollide = true
			end

			if v:IsA("BillboardGui") then
				v.Enabled = true
			end

			if CollectionService:HasTag(v, "LowTransparency") then
				v.CanCollide = true
				v.Transparency = 0.65
				continue
			end

			if v:IsA("ProximityPrompt") then
				if CollectionService:HasTag(v, "SelfEnabling") then
					return
				end
				v.Enabled = true
			end
			
			
			if v:IsA("SurfaceGui") then
				v.Enabled = true
			end

			if v:IsA("ProximityPrompt") then
				v.Enabled = true
			end

			if v:IsA("BasePart") and v.Parent.Name == "" then
				v.Transparency = 0.2
				continue
			end

			if v:IsA("BasePart") or v:IsA("UnionOperation") then
				if v.Name == "HumanoidRootPart" then
					v.Transparency = 1
					v.CanCollide = false
					continue
				end

				if CollectionService:HasTag(v, "Invisible") then
					v.Transparency = 1
					v.CanCollide = false
					continue
				elseif v.Name == "Window" then
					v.CanCollide = false
					continue
				end

				v.Transparency = 1 - progress

				if not CollectionService:HasTag(v, "NonCollidable") then
					v.CanCollide = true
				else
					v.CanCollide = false
				end
			end
		end

		task.wait(st)
	end

	
	local spawnPart = dropper:FindFirstChild("Spawn")
	self.Dropper = dropper
	if spawnPart and spawnPart:IsA("BasePart") then
		task.spawn(function()
			while self.Dropper do

				local part = Instance.new("Part")
				part.Size = Vector3.new(1,1,1)
				part.Material = Enum.Material.Neon
				part.BrickColor = BrickColor.new("Lime green")
				part.Anchored = false
				part.CanCollide = true
				part.CFrame = spawnPart.CFrame
				part.Name = "DropperPart"
				part.CollisionGroup = "DropperParts"
				part.Parent = self.DropperPartsFolder

				
				if dropper.Name == "GoldenDropper" then
					part.BrickColor = BrickColor.new("Gold")
				elseif dropper.Name == "EliteDropper" then
					part.BrickColor = BrickColor.new("Royal purple")
				end

			
				Debris:AddItem(part, 10)

				task.wait(2.5)
			end
		end)
	end
end

function Tycoon:_UnlockNextButtons(button)
	local unlocks = button:FindFirstChild("Unlocks")
	if not unlocks then return end

	for _, unlock in ipairs(unlocks:GetChildren()) do
		local nextButton = self.Buttons:FindFirstChild(unlock.Value)
		if nextButton then
			self:_ButtonFadeIn(nextButton)
		end
	end
end


function Tycoon:_ButtonFadeIn(button)
	button.CanCollide = true
	button.Transparency = 0

	local billboard = button:FindFirstChild("BillboardGui")
	if billboard then billboard.Enabled = true end

	local neon = button:FindFirstChild("Neon")

	TweenService:Create(
		button,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{Transparency = 0}
	):Play()

	if neon then
		TweenService:Create(
			neon,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{Transparency = 0}
		):Play()
	end
end



function Tycoon:_SetupCollector()
	local collector = self.MainItems.Conveyor1.Collector
	local Request : ProximityPrompt = self.ATM.Display.Request


	local BindableCheck = Instance.new("BindableEvent")
	BindableCheck.Name = "FriendService"
	self.FriendBindable = BindableCheck

	collector.Touched:Connect(function(hit)
		if hit.Name ~= "DropperPart" then return end

		local owner = self.OwnerValue.Value
		if not owner then return end -- Fix 2: guard against nil owner


		local currentMultiplier = owner:GetAttribute("Multiplier") or 1

		if self.PlayerService:HasFriendBoost(owner) then
			BindableCheck:Fire("Multiplier")
		end

		if hit.BrickColor == BrickColor.new("Lime green") then
			self.CollectorAmount += (15 * currentMultiplier)
		elseif hit.BrickColor == BrickColor.new("Gold") then
			self.CollectorAmount += (85 * currentMultiplier)
		elseif hit.BrickColor == BrickColor.new("Royal purple") then
			self.CollectorAmount += (225 * currentMultiplier)
		end

		self.ATM.Display.SurfaceGui.Money.Text = tostring(self.CollectorAmount)
		Debris:AddItem(hit, 0)
	end)

	BindableCheck.Event:Connect(function(arg)
		if arg == "Disconnected" then
			local owner = self.OwnerValue.Value
			if owner then
				local currentMultiplier = owner:GetAttribute("Multiplier") or 1
				if currentMultiplier > 1.1 then
					owner:SetAttribute("Multiplier", currentMultiplier - 1.1)
				else
					owner:SetAttribute("Multiplier", 1)
				end
			end
		end
	end)

	local debounce = false
	local cooldown = 3

	Request.Triggered:Connect(function(player)
		if player ~= self.OwnerValue.Value then return end
		if debounce then return end

		-- Fix 4: apply X2 multiplier at collect time, not on every dropper touch
		local finalAmount = self.CollectorAmount
		if self.PlayerService:HasX2(player) then
			finalAmount = finalAmount * 2
		end

		ProfileManager.AddCash(player, finalAmount)
		self.CollectorAmount = 0
		self.ATM.Display.SurfaceGui.Money.Text = "0"

		debounce = true
		task.wait(cooldown)
		debounce = false
	end)
end

function Tycoon:Cleanup()
	local previousOwner = self.OwnerValue.Value

	local door = self.MainItems.OwnerDoor.Door
	local titleLabel = self.MainItems.OwnerDoor.Title.SurfaceGui.TextLabel
	titleLabel.Text = "Unclaimed Tycoon"
	door.Transparency = 0.25
	
	self.ATM.Display.SurfaceGui.Money.Text = "0"
	self.CollectorAmount = 0

	if self.Buttons then
		self.Buttons:Destroy()

		self.Buttons = self.ButtonTemplate:Clone()
		self.Buttons.Parent = self.Model

		self:_SetupButtons()
	end

	self.Dropper = nil

	self:_RestoreMovedItems()

	for _, item in ipairs(self.PurchasedItems:GetChildren()) do
		item:Destroy()
	end



	if self.DropperPartsFolder then
		for _, part in ipairs(self.DropperPartsFolder:GetChildren()) do
			part:Destroy()
		end
	end

	self.Dropper = nil
	self.x2Upgraders = {}
	self.x3Upgraders = {}

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

function Tycoon:_SetupUpgraders()
	for _, item in ipairs(self.Droppers:GetChildren()) do
		self:_SetupUpgrader(item)
	end
end

function Tycoon:_SetupUpgrader(dropper)
	if not dropper or not dropper:IsA("Model") then
		return
	end

	if dropper:GetAttribute("UpgraderSetup") then
		return
	end

	local x2Part = dropper:FindFirstChild("x2")
	if x2Part and dropper.Name == "BasicUpgrader" then
		dropper:SetAttribute("UpgraderSetup", true)
		self.x2Upgraders[dropper.Name] = x2Part

		local touched = false
		x2Part.Touched:Connect(function(hit)
			if touched then return end
			if x2Part.Transparency >= 1 or hit.Name ~= "DropperPart" then return end

			local owner = self.OwnerValue.Value
			if not owner then return end

			local currentMultiplier = owner:GetAttribute("Multiplier") or 1
			if currentMultiplier == 1 then
				owner:SetAttribute("Multiplier", currentMultiplier * 2)
			else
				owner:SetAttribute("Multiplier", currentMultiplier + 2)
			end

			touched = true
		end)

		return
	end

	local x3Part = dropper:FindFirstChild("x3")
	if x3Part and dropper.Name == "EnchancedUpgrader" then
		dropper:SetAttribute("UpgraderSetup", true)
		self.x3Upgraders[dropper.Name] = x3Part

		local touched = false
		x3Part.Touched:Connect(function(hit)
			if touched then return end
			if x3Part.Transparency >= 1 or hit.Name ~= "DropperPart" then return end

			local owner = self.OwnerValue.Value
			if not owner then return end

			local currentMultiplier = owner:GetAttribute("Multiplier") or 1
			if currentMultiplier == 1 then
				owner:SetAttribute("Multiplier", currentMultiplier * 3)
			else
				owner:SetAttribute("Multiplier", currentMultiplier + 3)
			end

			touched = true
		end)
	end
end


function Tycoon:_SetupElectricity()
	local fuseBox = self.Stages.Stage2.ScientificLab.FUSE_BOX.FuseBox
	local prompt = fuseBox.FuseLeaver.Part.ProximityPrompt

	
	self.PurchasedItems.ChildAdded:Connect(function(child)
		if child.Name == "CeilingLights1" then
			
			if ReturnRequest then
				ReturnRequest:FireClient(self.OwnerValue.Value, "FuseBox")
			end
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

	
	for _, part in ipairs(CollectionService:GetTagged("ElectricityParts")) do
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or not player:GetAttribute("Power") then return end
			if self.PlayerService:IsElectrified(player) then return end

			self:_ElectrifyPlayer(player)
		end)
	end
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
		warn("On Debounce")
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


function Tycoon:_ElectrifyPlayer(player : Player)
	self.PlayerService:SetElectrified(player, true)
	
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end


	if humanoid then
		humanoid:UnequipTools()
	end


	task.wait(0.2)

local AnimBase = character:FindFirstChild("AnimBase")
	if player.Backpack then
		for _, tool in ipairs(player.Backpack:GetChildren()) do 
			if tool:IsA("Tool") then
				tool:Destroy()
				if AnimBase then
					AnimBase:Destroy()
				end
			end
		end
	end

	
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			tool:Destroy()
			
			if AnimBase then
				AnimBase:Destroy()
			end
		end
	end
	
	local Backup = ReplicatedStorage.ACS_Engine.GunModels
	
	for _, v in Backup:GetChildren() do
	local FindHiddenGun : Model = character:FindFirstChild(v.Name) or character:FindFirstChild("S".. v.Name)
	if FindHiddenGun then
			
		FindHiddenGun:Destroy()
	    end
	end

	
	task.wait(0.1)

	local char = player.Character
	local hum = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if hum then
		hum:TakeDamage(60)

	
		local lightning = VisualEffects.Lightining:Clone()
		lightning.Parent = hrp
		Debris:AddItem(lightning, 4)

		local velocity = Instance.new("BodyVelocity")
		velocity.MaxForce = Vector3.new(1e5, 0, 1e5)
		velocity.Velocity = -hrp.CFrame.LookVector * 50
		velocity.Parent = hrp
		Debris:AddItem(velocity, 1.5)


		if self.RagdollModule then
			self.RagdollModule.Ragdoll(player, 4)
		end

	
		local sound = script.Parent.Parent:FindFirstChild("Electrified")
		if sound then
			local soundClone = sound:Clone()
			soundClone.Parent = hrp
			soundClone:Play()
			Debris:AddItem(soundClone, soundClone.TimeLength)
		end
	end
ReturnRequest:FireClient(self.OwnerValue.Value, "Electrocuted")
	task.delay(5, function()
		self.PlayerService:SetElectrified(player, false)
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
					warn("This is the Tycoon Owner, cannot kill.")
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
