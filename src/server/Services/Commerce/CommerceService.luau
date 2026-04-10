

	local MarketplaceService = game:GetService("MarketplaceService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerStorage = game:GetService("ServerStorage")
	local TweenService = game:GetService("TweenService")


	local CommerceService = {}
	CommerceService.__index = CommerceService


	local PRODUCT_IDS = {
		Cash_5000 = 3450461469,
		Cash_25000 = 3450463123,
		Cash_50000 = 3450470672,
		Cash_250000 = 3450465321,
		Cash_500000 = 3450466129,

		Emerald_300 = 3496915650,
		Emerald_750 = 3496916844,
		Emerald_1250 = 3496917747,
		Emerald_3500 = 3496918338,
		Emerald_10000 = 3496921305,
		
		ShieldArmour = 3450473810,

		GoldenDropper = 3438520055,
	}

	local Tycoons = workspace.Tycoons


		


	local GAMEPASS_IDS = {
		RainbowCarpet = 1568782544,
		X2Cash = 1568972351,
		UltraExplosiveGun = 1571038036,
		SWAT_Gamepass = 1573236427,
	}


	function CommerceService.new(playerService)
		local self = setmetatable({}, CommerceService)

		self.PlayerService = playerService
		self.PurchaseHandlers = {}
		self.PendingPurchases = {}

		return self
	end


	function CommerceService:Init()
		self:_SetupProductHandlers()
		self:_SetupProcessReceipt()
		self:_SetupGamepassHandlers()


	end

	function CommerceService:_GiveShield(player : Player)
		local Shield : Model = ReplicatedStorage.GamePackage.CharacterItems.Shield:Clone()
		local character = player.Character
		
		if character:FindFirstChild("Shield") then return end
		local newWeld = Instance.new("Weld")
		
		

		newWeld.Part0 = player.Character["Left Arm"]
		newWeld.Part1 = Shield.PrimaryPart
		newWeld.Parent = Shield.PrimaryPart
		Shield.Parent = character


		newWeld.C0 = CFrame.new(-0.1, 0, 0) * CFrame.Angles(math.rad(90), 0, math.rad(-90))

		for _, v in player.Backpack:GetChildren() do
			if v:IsA("Tool") and v:FindFirstChild("ACS_Settings") then

				v:GetPropertyChangedSignal("Parent"):Connect(function()
					if v.Parent == player.Character then

						v.Equipped:Connect(function()

							newWeld.C0 = CFrame.new(-1.3, -0.45, 0.2) * CFrame.Angles(0,math.rad(70), math.rad(-20))

						end)

						v.Unequipped:Connect(function()
							newWeld.C0 = CFrame.new(-0.1, 0, 0) * CFrame.Angles(math.rad(90), 0, math.rad(-90))
						end)
					end
				end)

			end
		end
	end

	function CommerceService:_HK416(player : Player)
		local Guns = ServerStorage.Guns
		local HK416 = Guns:FindFirstChild("HK416"):Clone()
		HK416.Parent = player.Backpack
		
	if player.Backpack:FindFirstChild("HK416") or player.Character:FindFirstChild("HK416") then
		return
	end
	end


	function CommerceService:_Clothes(player : Player)
	local normalHealth = 100
		local character = player.Character or player.CharacterAdded:Wait()
		local CharacterItems = ReplicatedStorage.GamePackage.CharacterItems
		local Armour_Swat = CharacterItems.Armour.SWAT_Vest:Clone()
		local Humanoid : Humanoid = character:FindFirstChild("Humanoid")
		if not Humanoid then return end

		local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
		local FreeArmour = character:FindFirstChild("Armour1") or character:FindFirstChild("Armour2")
		
		if FreeArmour then
			task.delay(0, FreeArmour.Destroy, FreeArmour)
			player:SetAttribute("ArmourEquipped", false)
		end
		if torso then
			Armour_Swat.Parent = character
			local offset = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0)
			Armour_Swat:SetPrimaryPartCFrame(torso.CFrame * offset)
			local newWeld = Instance.new("WeldConstraint")
			newWeld.Part0 = torso
			newWeld.Part1 = Armour_Swat.Primary
			newWeld.Parent = Armour_Swat.Primary
			
			Humanoid.MaxHealth = 300
			Humanoid.Health = 300
			player:SetAttribute("ArmourEquipped", true)
		end


	local Humanoid : Humanoid = character:FindFirstChild("Humanoid")

	local description = Humanoid:GetAppliedDescription()

	description.Shirt = 6433605120
	description.Pants = 8883038978

	Humanoid:ApplyDescriptionAsync(description)
	end


	function CommerceService:_GiveRainbowCarpet(player : Player)
		if player.UserId ~= 1372952359 and player.UserId ~= 5330259633 then return end
		local item = ServerStorage.GamepassItems.RainbowCarpet:Clone()
		item.Parent = player.StarterGear
		item.Parent = player.Backpack

	end




	function CommerceService:OnTycoonClaimed(player, tycoon)

		self.PendingPurchases[player.UserId] = nil

		print(
			"Tycoon claimed:",
			tycoon.Model.Name,
			"by",
			player.Name
		)
	end


	function CommerceService:_SetupProductHandlers()
		
		self.PurchaseHandlers[PRODUCT_IDS.Cash_5000] = function(player)
			player.leaderstats.Cash.Value += 5000
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		self.PurchaseHandlers[PRODUCT_IDS.Cash_25000] = function(player)
			player.leaderstats.Cash.Value += 25000
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		self.PurchaseHandlers[PRODUCT_IDS.Cash_50000] = function(player)
			player.leaderstats.Cash.Value += 50000
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		self.PurchaseHandlers[PRODUCT_IDS.Cash_250000] = function(player)
			player.leaderstats.Cash.Value += 250000
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		self.PurchaseHandlers[PRODUCT_IDS.Cash_500000] = function(player)
			player.leaderstats.Cash.Value += 500000
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		
		self.PurchaseHandlers[PRODUCT_IDS.Emerald_300] = function(player)
			player.leaderstats.Emerald.Value += 300
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		self.PurchaseHandlers[PRODUCT_IDS.Emerald_750] = function(player)
			player.leaderstats.Emerald.Value += 750
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		self.PurchaseHandlers[PRODUCT_IDS.Emerald_1250] = function(player)
			player.leaderstats.Emerald.Value += 1250
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		self.PurchaseHandlers[PRODUCT_IDS.Emerald_3500] = function(player)
			player.leaderstats.Emerald.Value += 3500
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		self.PurchaseHandlers[PRODUCT_IDS.Emerald_10000] = function(player)
			player.leaderstats.Emerald.Value += 10000
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		
		self.PurchaseHandlers[PRODUCT_IDS.ShieldArmour] = function(player : Player)
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			local character = player.Character
			local newHighlight = Instance.new("Highlight")
			newHighlight.Parent = player.Character
			newHighlight.FillColor = Color3.new(0, 0.333333, 1)
			newHighlight.OutlineColor = Color3.new(1, 1, 0)
			newHighlight.FillTransparency = 0.85
			
			local sphere = Instance.new("Part")
			sphere.Name = "PowerSphere"
			sphere.Shape = Enum.PartType.Ball
			sphere.Material = Enum.Material.ForceField
			sphere.Size = Vector3.new(8, 8, 8)
			sphere.Parent = character
			
			
			sphere.CanCollide = false
			sphere.CanTouch = false
			sphere.CanQuery = false
			sphere.Anchored = false
			sphere.Massless = true
			
			
			sphere.Transparency = 1
			sphere.BrickColor = BrickColor.new("Really blue")
			sphere.CFrame = rootPart.CFrame 
			sphere.Parent = character

			
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rootPart
			weld.Part1 = sphere
			weld.Parent = sphere

	character.Humanoid.Health = math.huge

			task.spawn(function()


				local tween1 = TweenService:Create(sphere, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {Transparency = 0 })
				local tween2 = TweenService:Create(sphere, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Transparency = 1 })
				while task.wait(5) do
					tween1:Play()
					tween1.Completed:Wait()
					tween2:Play()

				end

			end)

	local Timer = 80

	while Timer > 0 do

		task.wait(1)
		Timer -= 1
		
		
	end

	if Timer == 0 then
		task.delay(0, sphere.Destroy, sphere)
		task.delay(0, weld.Destroy, weld)
		task.delay(0, newHighlight.Destroy, newHighlight)
	end
			
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end


	function CommerceService:_SetupProcessReceipt()
		MarketplaceService.ProcessReceipt = function(receiptInfo)
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if not player then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			local handler = self.PurchaseHandlers[receiptInfo.ProductId]
			if handler then
				return handler(player)
			end

			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end


function CommerceService:_SetupGamepassHandlers()

for _, Item in Tycoons:GetChildren() do
	local MainItems = Item:FindFirstChild("MainItems")
	local GamePassItems = MainItems:FindFirstChild("GamepassItems")
	local OwnerValue = Item:FindFirstChild("Values").OwnerValue

local SwatPass = GamePassItems["SWAT_Gamepass"]

for _, ClickDetector in GamePassItems:GetDescendants() do
if ClickDetector:IsA("ClickDetector") then
    local Activation: ClickDetector = ClickDetector
	Activation.MouseClick:Connect(function(player: Player)
		if OwnerValue.Value ~= player then
			return
		end
		
		
	local ModelParent: Model = Activation:FindFirstAncestorOfClass("Model")
	
	
	if not ModelParent then 
		return
	end
	
	
	if not player:FindFirstChild("hasTycoon").Value then 
		return
	end

	if ModelParent:HasTag("SWAT Riot") then
		if MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_IDS.SWAT_Gamepass) then


	if ModelParent.Name == "Shield" then
		self:_GiveShield(player)

		end

	if ModelParent.Name == "HK416" then
		self:_HK416(player)

	end

	if ModelParent.Name == "Clothes" then
		self:_Clothes(player)

	end
		else
			ReplicatedStorage.Remotes.ReturnRequest:FireClient(player, "Prompt")
			end
				end

			end)
		end
end
	
end

		
		Players.PlayerAdded:Connect(function(player)
		
			self:_CheckGamepassOwnership(player)
		end)


		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
			if not wasPurchased then return end

			if gamepassId == GAMEPASS_IDS.RainbowCarpet then
				self:_GiveRainbowCarpet(player)

			--elseif gamepassId == GAMEPASS_IDS.UltraExplosiveGun then
			--	self:_GiveRayGun(player)

			elseif gamepassId == GAMEPASS_IDS.X2Cash then
				self.PlayerService:SetX2(player, true)
			end
		end)
	end


	function CommerceService:_CheckGamepassOwnership(player)

	task.wait(2)
			if MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_IDS.RainbowCarpet) then
			self:_GiveRainbowCarpet(player)

			end

			if  MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_IDS.X2Cash) then
			self.PlayerService:SetX2(player, true)
			end

	end









	function CommerceService:PromptGamepass(player, button, tycoon)
		local productId = PRODUCT_IDS.GoldenDropper

		self.PendingPurchases[player.UserId] = {
			tycoon = tycoon,
			button = button,
			itemName = button:FindFirstChild("Dependency").Value
		}

		local serverReady = ReplicatedStorage:FindFirstChild("ServerIsReady")
		if serverReady then
			serverReady:FireClient(player, productId)
		end
	end


	function CommerceService:CompletePendingPurchase(player)
		local data = self.PendingPurchases[player.UserId]
		if not data then return end

		local tycoon = data.tycoon
		local button = data.button

		tycoon:_ApplyPurchasedButton(button)

		self.PendingPurchases[player.UserId] = nil

		
	end

	return CommerceService
