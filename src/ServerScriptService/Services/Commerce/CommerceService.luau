--!strict

--[[
	@class CommerceService

	@desc
	Handles all in-game commerce — Developer Product receipts, gamepass
	purchases, SWAT gamepass item clicks, and tycoon button gamepass prompts.
]]

--// Services

const MarketplaceService = game:GetService("MarketplaceService")
const CollectionService = game:GetService("CollectionService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const ProductRewards = require(script.Parent.Handlers.ProductRewards)
const GearDistribution = require(script.Parent.Handlers.GearDistribution)
const GamepassCache = require(script.Parent.GamepassCache)

--// Types

type ProfileManagerLike = {
	AddCash: (player: Player, amount: number) -> (),
	AddEmerald: (player: Player, amount: number) -> (),
}

type PurchaseHandler = (player: Player, profileManager: ProfileManagerLike) -> Enum.ProductPurchaseDecision

type TycoonPurchaseTarget = {
	_ApplyPurchasedButton: (self: TycoonPurchaseTarget, button: BasePart) -> (),
}

type PendingPurchase = {
	tycoon: TycoonPurchaseTarget?,
	button: BasePart?,
	gamepassId: number,
}

--// Constants

const DeveloperProducts = {
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

const Gamepasses: { [string]: number } = {
	RainbowCarpet = 1568782544,
	X2Cash = 1568972351,
	SWAT_Gamepass = 1573236427,
	Raygun = 1793083522,
	GoldenDropper = 1618227062,
}

const PRODUCT_CASH_REWARDS = {
	[DeveloperProducts.Cash_5000] = 5000,
	[DeveloperProducts.Cash_25000] = 25000,
	[DeveloperProducts.Cash_50000] = 50000,
	[DeveloperProducts.Cash_250000] = 250000,
	[DeveloperProducts.Cash_500000] = 500000,
}

const PRODUCT_EMERALD_REWARDS = {
	[DeveloperProducts.Emerald_300] = 300,
	[DeveloperProducts.Emerald_750] = 750,
	[DeveloperProducts.Emerald_1250] = 1250,
	[DeveloperProducts.Emerald_3500] = 3500,
	[DeveloperProducts.Emerald_10000] = 10000,
}

--// Micro-Optimisations

const math_max = math.max

--// Internal Utilities

const Schedule = function(Delay: number, Callback: () -> (), Name: string?, RepeatEvery: number?)
	ECS.createEntity({
		Name = Name or "CommerceScheduledTask",
		ScheduledTask = {
			delay = Delay,
			elapsed = 0,
			repeatEvery = RepeatEvery,
			callback = Callback,
		},
	})
end

const GetLeaderstatValue = function(Player: Player, StatName: string): NumberValue?
	local Leaderstats = Player:FindFirstChild("leaderstats")
	if not Leaderstats then
		return nil
	end

	local Stat = Leaderstats:FindFirstChild(StatName)
	if Stat and Stat:IsA("NumberValue") then
		return Stat
	end

	return nil
end

const AddLeaderstat = function(Player: Player, StatName: string, Amount: number)
	local Stat = GetLeaderstatValue(Player, StatName)
	if Stat then
		Stat.Value += Amount
	end
end

const ResolveButtonGamepassId = function(Button: BasePart, GamepassKey: string?): number?
	if GamepassKey then
		return Gamepasses[GamepassKey]
	end

	return Gamepasses[Button.Name]
end

--// Module

const CommerceService = {}
CommerceService.__index = CommerceService

--// Constructor

function CommerceService.new(PlayerService: any): any
	local Self = setmetatable({}, CommerceService)
	Self.PlayerService = PlayerService
	Self.ProfileManager = ProfileManager
	Self.PurchaseHandlers = {} :: { [number]: PurchaseHandler }
	Self.PendingPurchases = {} :: { [Player]: PendingPurchase }
	Self.GamepassCache = GamepassCache.new()
	Self.GamepassCache:RegisterGamepass(Gamepasses.RainbowCarpet, "RainbowCarpet")
	Self.GamepassCache:RegisterGamepass(Gamepasses.Raygun, "Raygun")
	Self.GamepassCache:RegisterGamepass(Gamepasses.X2Cash, "X2Cash")
	Self.GamepassCache:RegisterGamepass(Gamepasses.SWAT_Gamepass, "SWAT_Gamepass")
	Self.GamepassCache:RegisterGamepass(Gamepasses.GoldenDropper, "GoldenDropper")
	return Self
end

--// Public API

function CommerceService:Init()
	self:_SetupProductHandlers()
	self:_SetupProcessReceipt()
	self:_SetupGamepassHandlers()
end

function CommerceService:_GiveShield(Player: Player)
	GearDistribution.GiveShield(Player)
end

function CommerceService:_HK416(Player: Player)
	GearDistribution.GiveHK416(Player)
end

function CommerceService:_Clothes(Player: Player)
	GearDistribution.GiveClothes(Player)
end

function CommerceService:_GiveRainbowCarpet(Player: Player)
	GearDistribution.GiveRainbowCarpet(Player)
end

function CommerceService:_GiveRayGun(Player: Player)
	GearDistribution.GiveRayGun(Player)
end

--// Internal Methods — Setup

function CommerceService:_SetupProductHandlers()
	for ProductId, CashAmount in pairs(PRODUCT_CASH_REWARDS) do
		self.PurchaseHandlers[ProductId] = function(Player: Player)
			AddLeaderstat(Player, "Cash", CashAmount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	for ProductId, EmeraldAmount in pairs(PRODUCT_EMERALD_REWARDS) do
		self.PurchaseHandlers[ProductId] = function(Player: Player)
			AddLeaderstat(Player, "Emerald", EmeraldAmount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	for ProductId, Handler in pairs(ProductRewards) do
		self.PurchaseHandlers[ProductId] = Handler
	end
end

function CommerceService:_SetupProcessReceipt()
	MarketplaceService.ProcessReceipt = function(ReceiptInfo)
		local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
		if not Player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local Handler = self.PurchaseHandlers[ReceiptInfo.ProductId]
		if Handler then
			local Success, Decision = xpcall(function()
				return Handler(Player, self.ProfileManager)
			end, debug.traceback)
			if not Success then
				warn(
					`[CommerceService] Receipt {tostring(ReceiptInfo.PurchaseId)} failed for {Player.Name}:\n{Decision}`
				)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			return Decision
		end

		warn(
			`[CommerceService] No receipt handler exists for product {ReceiptInfo.ProductId} (purchase {tostring(ReceiptInfo.PurchaseId)})`
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function CommerceService:_HandleSWATItemClick(Player: Player, ModelParent: Model, TycoonModel: Model)
	local OwnedTycoon = self.PlayerService:GetTycoon(Player)
	if not OwnedTycoon or OwnedTycoon.Model ~= TycoonModel then
		return
	end

	if not CollectionService:HasTag(ModelParent, "SWAT Riot") then
		return
	end

	if not self.GamepassCache:Has(Player, Gamepasses.SWAT_Gamepass) then
		MarketplaceService:PromptGamePassPurchase(Player, Gamepasses.SWAT_Gamepass)
		return
	end

	if ModelParent.Name == "Shield" then
		self:_GiveShield(Player)
	elseif ModelParent.Name == "HK416" then
		self:_HK416(Player)
	elseif ModelParent.Name == "Clothes" then
		self:_Clothes(Player)
	end
end

function CommerceService:_SetupSWATGamepassClickHandlers()
	local TycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not TycoonsFolder then
		return
	end

	for _, TycoonModel in TycoonsFolder:GetChildren() do
		if not TycoonModel:IsA("Model") then
			continue
		end

		local MainItems = TycoonModel:FindFirstChild("MainItems")
		if not MainItems then
			continue
		end

		local GamepassItems = MainItems:FindFirstChild("GamepassItems")
		if not GamepassItems then
			continue
		end

		-- Search all descendants for models tagged "SWAT Riot" (Clothes, HK416, Shield).
		-- Each of these models has a ClickDetector child named "Activation".
		for _, Descendant in GamepassItems:GetDescendants() do
			if Descendant:IsA("Model") and CollectionService:HasTag(Descendant, "SWAT Riot") then
				local ClickDetector = Descendant:FindFirstChildWhichIsA("ClickDetector")
				if ClickDetector then
					ClickDetector.MouseClick:Connect(function(Player: Player)
						self:_HandleSWATItemClick(Player, Descendant, TycoonModel)
					end)
				end
			end
		end
	end
end

function CommerceService:_SetupGamepassHandlers()
	self:_SetupSWATGamepassClickHandlers()

	Players.PlayerAdded:Connect(function(Player: Player)
		self:_CheckGamepassOwnership(Player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(Player: Player, GamepassId: number, WasPurchased: boolean)
			if WasPurchased then
				self.GamepassCache:SetOwned(Player, GamepassId, true)
			elseif not self.GamepassCache:Has(Player, GamepassId) then
				-- Player cancelled the purchase and doesn't own the gamepass.
				return
			end

			-- Reward logic runs for both new purchases and the "already owned" case.
			if GamepassId == Gamepasses.RainbowCarpet then
				self:_GiveRainbowCarpet(Player)
			elseif GamepassId == Gamepasses.Raygun then
				self:_GiveRayGun(Player)
			elseif GamepassId == Gamepasses.X2Cash then
				self.PlayerService:SetX2(Player, true)
			end

			self:CompletePendingPurchase(Player, GamepassId)
		end
	)
end

function CommerceService:_CheckGamepassOwnership(Player: Player)
	Schedule(2, function()
		if not Player.Parent then
			return
		end

		self.GamepassCache:Warm(Player)

		if self.GamepassCache:Has(Player, Gamepasses.RainbowCarpet) then
			self:_GiveRainbowCarpet(Player)
		end

		if self.GamepassCache:Has(Player, Gamepasses.Raygun) then
			self:_GiveRayGun(Player)
		end

		if self.GamepassCache:Has(Player, Gamepasses.X2Cash) then
			self.PlayerService:SetX2(Player, true)
		end
	end, "Commerce:GamepassOwnershipCheck")
end

function CommerceService:PromptGamepass(
	Player: Player,
	Button: BasePart,
	Tycoon: TycoonPurchaseTarget,
	GamepassKey: string?
)
	local GamepassId = ResolveButtonGamepassId(Button, GamepassKey)
	if not GamepassId then
		warn(`[CommerceService] Could not resolve gamepass id for button "{Button.Name}"`)
		return
	end

	-- If the cache doesn't have this gamepass yet (e.g. Warm hasn't completed),
	-- do a fresh synchronous check with Roblox before prompting.
	if not self.GamepassCache:Has(Player, GamepassId) then
		pcall(function()
			self.GamepassCache:Refresh(Player, GamepassId)
		end)
	end

	if self.GamepassCache:Has(Player, GamepassId) then
		Tycoon:_ApplyPurchasedButton(Button)
		return
	end

	self.PendingPurchases[Player] = {
		tycoon = Tycoon,
		button = Button,
		gamepassId = GamepassId,
	}
	MarketplaceService:PromptGamePassPurchase(Player, GamepassId)
end

function CommerceService:CompletePendingPurchase(Player: Player, PurchasedGamepassId: number?)
	local Data = self.PendingPurchases[Player]
	if not Data then
		return
	end

	if PurchasedGamepassId and Data.gamepassId ~= PurchasedGamepassId then
		return
	end

	local Tycoon = Data.tycoon
	local Button = Data.button
	if Tycoon and Button and Button.Parent then
		Tycoon:_ApplyPurchasedButton(Button)
	end

	self.PendingPurchases[Player] = nil
end

return CommerceService

