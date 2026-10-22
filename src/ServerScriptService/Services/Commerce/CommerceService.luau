--!strict

--[[
	@class CommerceService

	@desc
	Handles developer product receipts, gamepass purchases, SWAT gamepass item
	clicks, and tycoon button gamepass prompts.
]]

--// Services

const MarketplaceService = game:GetService("MarketplaceService")
const CollectionService = game:GetService("CollectionService")
const Players = game:GetService("Players")
const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Observers = require(ReplicatedStorage.Packages.Observers)

--// Modules

const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const ProductRewards = require(script.Parent.Handlers.ProductRewards)
const GearDistribution = require(script.Parent.Handlers.GearDistribution)
const GamepassCache = require(script.Parent.GamepassCache)
const TycoonRuntime = require(ServerScriptService.ECS.TycoonRuntime)
const TycoonFactory = require(ServerScriptService.ECS.TycoonFactory)

--// Types

type ProfileManagerLike = {
	AddCash: (Player: Player, Amount: number) -> (),
	AddEmerald: (Player: Player, Amount: number) -> (),
}

type PurchaseHandler = (Player: Player, ProfileManager: ProfileManagerLike) -> Enum.ProductPurchaseDecision

type TycoonPurchaseTarget = number

type PendingPurchase = {
	Tycoon: TycoonPurchaseTarget?,
	Button: BasePart?,
	GamepassId: number,
}
type ProcessingReceiptSet = { [string]: boolean }

--// Constants

const GamepassIds: { [string]: number } = {
	RainbowCarpet = 1568782544,
	X2Cash = 1568972351,
	SWAT_Gamepass = 1573236427,
	Raygun = 1793083522,
	GoldenDropper = 1618227062,
}

const ProcessingReceipts: { [any]: ProcessingReceiptSet } = setmetatable({}, { __mode = "k" })

local function ResolveButtonGamepassId(Button: BasePart, GamepassKey: string?): number?
	if GamepassKey then
		return GamepassIds[GamepassKey]
	end

	return GamepassIds[Button.Name]
end

local function IsReceiptSaved(Profile: any, PurchaseId: string): boolean
	const SavedData = Profile.LastSavedData
	if type(SavedData) ~= "table" then
		return false
	end

	const SavedReceipts = SavedData.ProcessedReceipts
	return type(SavedReceipts) == "table" and SavedReceipts[PurchaseId] ~= nil
end

local function WaitForReceiptSave(Profile: any, PurchaseId: string): boolean
	if IsReceiptSaved(Profile, PurchaseId) then
		return true
	end

	if not Profile:IsActive() then
		return false
	end

	Profile:Save()
	const Deadline = os.clock() + 15
	while os.clock() < Deadline do
		if IsReceiptSaved(Profile, PurchaseId) then
			return true
		end
		if not Profile:IsActive() then
			return false
		end
		task.wait(0.1)
	end

	return IsReceiptSaved(Profile, PurchaseId)
end

--// Module

const CommerceService = {}
CommerceService.__index = CommerceService

--// Constructor

function CommerceService.new(PlayerService: any): any
	const Self = setmetatable({}, CommerceService)
	Self.PlayerService = PlayerService
	Self.ProfileManager = ProfileManager
	Self.PurchaseHandlers = {} :: { [number]: PurchaseHandler }
	Self.PendingPurchases = setmetatable({}, { __mode = "k" }) :: { [Player]: PendingPurchase }
	Self.GamepassCache = GamepassCache.new()
	Self.GamepassCache:RegisterGamepass(GamepassIds.RainbowCarpet, "RainbowCarpet")
	Self.GamepassCache:RegisterGamepass(GamepassIds.Raygun, "Raygun")
	Self.GamepassCache:RegisterGamepass(GamepassIds.X2Cash, "X2Cash")
	Self.GamepassCache:RegisterGamepass(GamepassIds.SWAT_Gamepass, "SWAT_Gamepass")
	Self.GamepassCache:RegisterGamepass(GamepassIds.GoldenDropper, "GoldenDropper")
	return Self
end

--// Public API

function CommerceService:Init()
	self:_SetupProductHandlers()
	self:_SetupProcessReceipt()
	self:_SetupGamepassHandlers()
	Observers.observePlayer(function(Player: Player)
		return function()
			self.PendingPurchases[Player] = nil
		end
	end)
end

--// Internal Methods -- Setup

function CommerceService:_SetupProductHandlers()
	for ProductId, Handler in ProductRewards do
		self.PurchaseHandlers[ProductId] = Handler
	end
end

function CommerceService:_SetupProcessReceipt()
	MarketplaceService.ProcessReceipt = function(ReceiptInfo)
		const Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
		if not Player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		const Profile = self.ProfileManager.Profiles[Player]
		if not Profile or not Profile:IsActive() then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		const Handler = self.PurchaseHandlers[ReceiptInfo.ProductId]
		if not Handler then
			warn(
				`[CommerceService] No receipt handler exists for product {ReceiptInfo.ProductId} (purchase {tostring(ReceiptInfo.PurchaseId)})`
			)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		const PurchaseId = tostring(ReceiptInfo.PurchaseId)
		local Receipts = Profile.Data.ProcessedReceipts
		if Receipts == nil then
			Receipts = {}
			Profile.Data.ProcessedReceipts = Receipts
		elseif type(Receipts) ~= "table" then
			warn(`[CommerceService] Invalid receipt history for {Player.Name}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local Processing = ProcessingReceipts[Profile]
		if not Processing then
			Processing = {}
			ProcessingReceipts[Profile] = Processing
		end

		if Receipts[PurchaseId] == nil then
			if Processing[PurchaseId] then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			Processing[PurchaseId] = true
			const Success, Decision = xpcall(function()
				return Handler(Player, self.ProfileManager)
			end, debug.traceback)
			Processing[PurchaseId] = nil

			if not Success then
				warn("[CommerceService] Receipt handler failed for " .. Player.Name .. ": " .. tostring(Decision))
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if Decision ~= Enum.ProductPurchaseDecision.PurchaseGranted then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			Receipts[PurchaseId] = os.time()
		end

		const SaveSuccess, Saved = xpcall(function()
			return WaitForReceiptSave(Profile, PurchaseId)
		end, debug.traceback)
		if not SaveSuccess then
			warn(`[CommerceService] Could not save receipt {PurchaseId} for {Player.Name}:\n{Saved}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		return if Saved then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function CommerceService:_HandleSWATItemClick(Player: Player, ModelParent: Model, TycoonModel: Model)
	const OwnedTycoon = self.PlayerService:GetTycoon(Player)
	if not OwnedTycoon or TycoonFactory.getModel(OwnedTycoon) ~= TycoonModel then
		return
	end

	if not CollectionService:HasTag(ModelParent, "SWAT Riot") then
		return
	end

	local Ownership = self.GamepassCache:GetOwnership(Player, GamepassIds.SWAT_Gamepass)
	if Ownership == nil then
		const Success, Result = pcall(function()
			return self.GamepassCache:Refresh(Player, GamepassIds.SWAT_Gamepass)
		end)
		if not Success then
			warn(`[CommerceService] SWAT ownership check failed for {Player.Name}: {Result}`)
			return
		end
		Ownership = Result
	end
	if Ownership == nil or Player.Parent ~= Players then
		return
	end
	if not Ownership then
		MarketplaceService:PromptGamePassPurchase(Player, GamepassIds.SWAT_Gamepass)
		return
	end

	if ModelParent.Name == "Shield" then
		GearDistribution.GiveShield(Player)
	elseif ModelParent.Name == "HK416" then
		GearDistribution.GiveHK416(Player)
	elseif ModelParent.Name == "Clothes" then
		GearDistribution.GiveClothes(Player)
	end
end

function CommerceService:_SetupSWATGamepassClickHandlers()
	const TycoonsFolder = workspace:FindFirstChild("Tycoons")
	if not TycoonsFolder then
		return
	end

	for _, TycoonModel in TycoonsFolder:GetChildren() do
		if not TycoonModel:IsA("Model") then
			continue
		end

		const MainItems = TycoonModel:FindFirstChild("MainItems")
		if not MainItems then
			continue
		end

		const GamepassItems = MainItems:FindFirstChild("GamepassItems")
		if not GamepassItems then
			continue
		end

		-- Search all descendants for models tagged "SWAT Riot" (Clothes, HK416, Shield).
		-- Each of these models has a ClickDetector child named "Activation".
		for _, Descendant in GamepassItems:GetDescendants() do
			if Descendant:IsA("Model") and CollectionService:HasTag(Descendant, "SWAT Riot") then
				const ClickDetector = Descendant:FindFirstChildWhichIsA("ClickDetector")
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

	Observers.observePlayer(function(Player: Player)
		self:_CheckGamepassOwnership(Player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(Player: Player, GamepassId: number, WasPurchased: boolean)
			if WasPurchased then
				self.GamepassCache:SetOwned(Player, GamepassId, true)
			elseif not self.GamepassCache:Has(Player, GamepassId) then
				-- Player cancelled the purchase and does not own the gamepass.
				return
			end

			-- Reward logic runs for both new purchases and the already-owned case.
			if GamepassId == GamepassIds.RainbowCarpet then
				GearDistribution.GiveRainbowCarpet(Player)
			elseif GamepassId == GamepassIds.Raygun then
				GearDistribution.GiveRayGun(Player)
			elseif GamepassId == GamepassIds.X2Cash then
				self.PlayerService:SetX2(Player, true)
			end

			self:CompletePendingPurchase(Player, GamepassId)
		end
	)
end

function CommerceService:_CheckGamepassOwnership(Player: Player)
	task.delay(2, function()
		if not Player.Parent then
			return
		end

		self.GamepassCache:Warm(Player)

		if self.GamepassCache:Has(Player, GamepassIds.RainbowCarpet) then
			GearDistribution.GiveRainbowCarpet(Player)
		end

		if self.GamepassCache:Has(Player, GamepassIds.Raygun) then
			GearDistribution.GiveRayGun(Player)
		end

		if self.GamepassCache:Has(Player, GamepassIds.X2Cash) then
			self.PlayerService:SetX2(Player, true)
		end
	end)
end

function CommerceService:PromptGamepass(
	Player: Player,
	Button: BasePart,
	Tycoon: TycoonPurchaseTarget,
	GamepassKey: string?
)
	const GamepassId = ResolveButtonGamepassId(Button, GamepassKey)
	if not GamepassId then
		warn(`[CommerceService] Could not resolve gamepass id for button "{Button.Name}"`)
		return
	end

	local Ownership = self.GamepassCache:GetOwnership(Player, GamepassId)
	if Ownership == nil then
		const Success, Result = pcall(function()
			return self.GamepassCache:Refresh(Player, GamepassId)
		end)
		if not Success then
			warn(`[CommerceService] Ownership check failed for {Player.Name}, pass {GamepassId}: {Result}`)
			return
		end
		Ownership = Result
	end

	if Ownership == nil or Player.Parent ~= Players then
		return
	end

	if Ownership then
		TycoonRuntime.applyPurchasedButton(Tycoon, Button)
		return
	end

	self.PendingPurchases[Player] = {
		Tycoon = Tycoon,
		Button = Button,
		GamepassId = GamepassId,
	}
	MarketplaceService:PromptGamePassPurchase(Player, GamepassId)
end

function CommerceService:CompletePendingPurchase(Player: Player, PurchasedGamepassId: number?)
	const Data = self.PendingPurchases[Player]
	if not Data then
		return
	end

	if PurchasedGamepassId and Data.GamepassId ~= PurchasedGamepassId then
		return
	end

	const Tycoon = Data.Tycoon
	const Button = Data.Button
	if Tycoon and Button and Button.Parent then
		TycoonRuntime.applyPurchasedButton(Tycoon, Button)
	end

	self.PendingPurchases[Player] = nil
end

return CommerceService
