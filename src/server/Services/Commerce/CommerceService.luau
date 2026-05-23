--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
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
}

local GAMEPASS_IDS: { [string]: number } = {
	RainbowCarpet = 1568782544,
	X2Cash = 1568972351,
	SWAT_Gamepass = 1573236427,
	Raygun = 1793083522,
	GoldenDropper = 3438520055,
}

local PRODUCT_CASH_REWARDS = {
	[PRODUCT_IDS.Cash_5000] = 5000,
	[PRODUCT_IDS.Cash_25000] = 25000,
	[PRODUCT_IDS.Cash_50000] = 50000,
	[PRODUCT_IDS.Cash_250000] = 250000,
	[PRODUCT_IDS.Cash_500000] = 500000,
}

local PRODUCT_EMERALD_REWARDS = {
	[PRODUCT_IDS.Emerald_300] = 300,
	[PRODUCT_IDS.Emerald_750] = 750,
	[PRODUCT_IDS.Emerald_1250] = 1250,
	[PRODUCT_IDS.Emerald_3500] = 3500,
	[PRODUCT_IDS.Emerald_10000] = 10000,
}

type PendingPurchase = {
	tycoon: any,
	button: BasePart,
	gamepassId: number,
}

local function getLeaderstatValue(player: Player, statName: string): NumberValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	local stat = leaderstats:FindFirstChild(statName)
	if stat and stat:IsA("NumberValue") then
		return stat
	end

	return nil
end

local function addLeaderstat(player: Player, statName: string, amount: number)
	local stat = getLeaderstatValue(player, statName)
	if stat then
		stat.Value += amount
	end
end

local function hasTool(player: Player, toolName: string): boolean
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local starterGear = player:FindFirstChild("StarterGear")

	if backpack and backpack:FindFirstChild(toolName) then
		return true
	end

	if character and character:FindFirstChild(toolName) then
		return true
	end

	if starterGear and starterGear:FindFirstChild(toolName) then
		return true
	end

	return false
end

local function resolveButtonGamepassId(button: BasePart): number?
	local gamepassValue = button:FindFirstChild("Gamepass")
	if gamepassValue then
		if gamepassValue:IsA("IntValue") or gamepassValue:IsA("NumberValue") then
			local id = gamepassValue.Value
			if id > 0 then
				return id
			end
		elseif gamepassValue:IsA("StringValue") then
			local key = gamepassValue.Value
			local mapped = GAMEPASS_IDS[key]
			if mapped then
				return mapped
			end
		end
	end

	return GAMEPASS_IDS[button.Name]
end

function CommerceService.new(playerService)
	local self = setmetatable({}, CommerceService)
	self.PlayerService = playerService
	self.PurchaseHandlers = {}
	self.PendingPurchases = {} :: { [number]: PendingPurchase }
	self.TycoonsByOwnerUserId = {} :: { [number]: any }
	return self
end

function CommerceService:Init()
	self:_SetupProductHandlers()
	self:_SetupProcessReceipt()
	self:_SetupGamepassHandlers()
end

function CommerceService:_GiveShield(player: Player)
	local character = player.Character
	if not character then
		return
	end

	if character:FindFirstChild("Shield") then
		return
	end

	local leftArm = character:FindFirstChild("Left Arm")
	if not leftArm or not leftArm:IsA("BasePart") then
		return
	end

	local shieldTemplate = ReplicatedStorage:FindFirstChild("GamePackage")
		and (ReplicatedStorage.GamePackage :: Folder):FindFirstChild("CharacterItems")
		and ReplicatedStorage.GamePackage.CharacterItems:FindFirstChild("Shield")
	if not shieldTemplate or not shieldTemplate:IsA("Model") then
		return
	end

	local shield = shieldTemplate:Clone()
	if not shield.PrimaryPart then
		return
	end

	local weld = Instance.new("Weld")
	weld.Part0 = leftArm
	weld.Part1 = shield.PrimaryPart
	weld.C0 = CFrame.new(-0.1, 0, 0) * CFrame.Angles(math.rad(90), 0, math.rad(-90))
	weld.Parent = shield.PrimaryPart
	shield.Parent = character
end

function CommerceService:_HK416(player: Player)
	if hasTool(player, "HK416") then
		return
	end

	local guns = ServerStorage:FindFirstChild("Guns")
	if not guns then
		return
	end

	local hk = guns:FindFirstChild("HK416")
	if hk and hk:IsA("Tool") then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			hk:Clone().Parent = backpack
		end
	end
end

function CommerceService:_Clothes(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso or not torso:IsA("BasePart") then
		return
	end

	local gamePackage = ReplicatedStorage:FindFirstChild("GamePackage")
	if not gamePackage then
		return
	end

	local characterItems = (gamePackage :: Folder):FindFirstChild("CharacterItems")
	if not characterItems then
		return
	end

	local armourFolder = (characterItems :: Folder):FindFirstChild("Armour")
	local swatVest = armourFolder and armourFolder:FindFirstChild("SWAT_Vest")
	if swatVest and swatVest:IsA("Model") and swatVest.PrimaryPart then
		local vest = swatVest:Clone()
		vest.Parent = character
		vest:PivotTo(torso.CFrame * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0))

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = vest.PrimaryPart :: BasePart
		weld.Parent = vest.PrimaryPart
	end

	humanoid.MaxHealth = 300
	humanoid.Health = 300
	player:SetAttribute("ArmourEquipped", true)

	local description = humanoid:GetAppliedDescription()
	description.Shirt = 6433605120
	description.Pants = 8883038978
	humanoid:ApplyDescriptionAsync(description)
end

function CommerceService:_GiveRainbowCarpet(player: Player)
	if hasTool(player, "RainbowCarpet") then
		return
	end

	local item = ServerStorage:FindFirstChild("GamepassItems")
		and (ServerStorage.GamepassItems :: Folder):FindFirstChild("RainbowCarpet")
	if not item or not item:IsA("Tool") then
		return
	end

	local starterGear = player:FindFirstChild("StarterGear")
	local backpack = player:FindFirstChild("Backpack")
	if starterGear then
		item:Clone().Parent = starterGear
	end
	if backpack then
		item:Clone().Parent = backpack
	end
end

function CommerceService:_GiveRayGun(player: Player)
	if hasTool(player, "Raygun") then
		return
	end

	local item = ServerStorage:FindFirstChild("GamepassItems")
		and (ServerStorage.GamepassItems :: Folder):FindFirstChild("Raygun")
	if not item or not item:IsA("Tool") then
		return
	end

	local starterGear = player:FindFirstChild("StarterGear")
	local backpack = player:FindFirstChild("Backpack")
	if starterGear then
		item:Clone().Parent = starterGear
	end
	if backpack then
		item:Clone().Parent = backpack
	end
end

function CommerceService:_SetupProductHandlers()
	for productId, cashAmount in pairs(PRODUCT_CASH_REWARDS) do
		self.PurchaseHandlers[productId] = function(player: Player)
			addLeaderstat(player, "Cash", cashAmount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	for productId, emeraldAmount in pairs(PRODUCT_EMERALD_REWARDS) do
		self.PurchaseHandlers[productId] = function(player: Player)
			addLeaderstat(player, "Emerald", emeraldAmount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	self.PurchaseHandlers[PRODUCT_IDS.ShieldArmour] = function(player: Player)
		local character = player.Character
		if not character then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not rootPart or not humanoid then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.new(0, 0.333333, 1)
		highlight.OutlineColor = Color3.new(1, 1, 0)
		highlight.FillTransparency = 0.85
		highlight.Parent = character

		local sphere = Instance.new("Part")  :: Part
		sphere.Name = "PowerSphere"
		sphere.Shape = Enum.PartType.Ball
		sphere.Material = Enum.Material.ForceField
		sphere.Size = Vector3.new(8, 8, 8)
		sphere.CanCollide = false
		sphere.CanTouch = false
		sphere.CanQuery = false
		sphere.Anchored = false
		sphere.Massless = true
		sphere.Transparency = 1
		sphere.CFrame = rootPart.CFrame
		sphere.Parent = character

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootPart
		weld.Part1 = sphere
		weld.Parent = sphere

		humanoid.Health = math.huge

		task.spawn(function()
			local tweenIn = TweenService:Create(sphere, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In), { Transparency = 0 })
			local tweenOut = TweenService:Create(sphere, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { Transparency = 1 })
			while sphere.Parent do
				task.wait(5)
				tweenIn:Play()
				tweenIn.Completed:Wait()
				tweenOut:Play()
			end
		end)

		task.delay(80, function()
			if sphere.Parent then
				sphere:Destroy()
			end
			if highlight.Parent then
				highlight:Destroy()
			end
			if weld.Parent then
				weld:Destroy()
			end
		end)

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

function CommerceService:_HandleSWATItemClick(player: Player, modelParent: Model, ownerValue: ObjectValue)
	if ownerValue.Value ~= player then
		return
	end

	local hasTycoon = player:FindFirstChild("hasTycoon")
	if not hasTycoon or not hasTycoon:IsA("BoolValue") or not hasTycoon.Value then
		return
	end

	if not CollectionService:HasTag(modelParent, "SWAT Riot") then
		return
	end

	local ownsPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_IDS.SWAT_Gamepass)
	if not ownsPass then
		MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_IDS.SWAT_Gamepass)
		return
	end

	if modelParent.Name == "Shield" then
		self:_GiveShield(player)
	elseif modelParent.Name == "HK416" then
		self:_HK416(player)
	elseif modelParent.Name == "Clothes" then
		self:_Clothes(player)
	end
end

function CommerceService:_SetupSWATGamepassClickHandlers()
	local tycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not tycoonsFolder then
		return
	end

	for _, tycoonModel in tycoonsFolder:GetChildren() do
		local mainItems = tycoonModel:FindFirstChild("MainItems")
		local values = tycoonModel:FindFirstChild("Values")
		if not mainItems or not values then
			continue
		end

		local ownerValue = values:FindFirstChild("OwnerValue")
		local gamepassItems = mainItems:FindFirstChild("GamepassItems")
		if not ownerValue or not ownerValue:IsA("ObjectValue") or not gamepassItems then
			continue
		end

		for _, descendant in gamepassItems:GetDescendants() do
			if descendant:IsA("ClickDetector") then
				descendant.MouseClick:Connect(function(player: Player)
					local modelParent = descendant:FindFirstAncestorOfClass("Model")
					if not modelParent then
						return
					end
					self:_HandleSWATItemClick(player, modelParent, ownerValue)
				end)
			end
		end
	end
end

function CommerceService:_SetupGamepassHandlers()
	self:_SetupSWATGamepassClickHandlers()

	Players.PlayerAdded:Connect(function(player: Player)
		self:_CheckGamepassOwnership(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamepassId: number, wasPurchased: boolean)
		if not wasPurchased then
			return
		end

		if gamepassId == GAMEPASS_IDS.RainbowCarpet then
			self:_GiveRainbowCarpet(player)
		elseif gamepassId == GAMEPASS_IDS.Raygun then
			self:_GiveRayGun(player)
		elseif gamepassId == GAMEPASS_IDS.X2Cash then
			self.PlayerService:SetX2(player, true)
		end

		self:CompletePendingPurchase(player, gamepassId)
	end)
end

function CommerceService:_CheckGamepassOwnership(player: Player)
	task.wait(2)

	if MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_IDS.RainbowCarpet) then
		self:_GiveRainbowCarpet(player)
	end

	if MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_IDS.Raygun) then
		self:_GiveRayGun(player)
	end

	if MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_IDS.X2Cash) then
		self.PlayerService:SetX2(player, true)
	end
end

function CommerceService:OnTycoonClaimed(player: Player, tycoon)
	self.TycoonsByOwnerUserId[player.UserId] = tycoon
end

function CommerceService:PromptGamepass(player: Player, button: BasePart, tycoon)
	local gamepassId = resolveButtonGamepassId(button)
	if not gamepassId then
		warn(`[CommerceService] Could not resolve gamepass id for button "{button.Name}"`)
		return
	end

	local ownsPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	if ownsPass then
		tycoon:_ApplyPurchasedButton(button)
		return
	end

	self.PendingPurchases[player.UserId] = {
		tycoon = tycoon,
		button = button,
		gamepassId = gamepassId,
	}
	MarketplaceService:PromptGamePassPurchase(player, gamepassId)
end

function CommerceService:CompletePendingPurchase(player: Player, purchasedGamepassId: number?)
	local data = self.PendingPurchases[player.UserId]
	if not data then
		return
	end

	if purchasedGamepassId and data.gamepassId ~= purchasedGamepassId then
		return
	end

	local tycoon = data.tycoon
	local button = data.button
	if tycoon and button and button.Parent then
		tycoon:_ApplyPurchasedButton(button)
	end

	self.PendingPurchases[player.UserId] = nil
end

return CommerceService
