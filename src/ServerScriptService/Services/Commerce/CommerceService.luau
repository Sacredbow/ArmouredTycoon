--!strict

--[[
	@class CommerceService

	@desc
	Handles all in-game commerce â€” Developer Product receipts, gamepass
	purchases, SWAT gamepass item clicks, and tycoon button gamepass prompts.
]]

--// Services

local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

--// Modules

local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local ProductRewards = require(script.Parent.Handlers.ProductRewards)
local GearDistribution = require(script.Parent.Handlers.GearDistribution)
local GamepassCache = require(script.Parent.GamepassCache)
local TycoonRuntime = require(ServerScriptService.ECS.TycoonRuntime)
local TycoonFactory = require(ServerScriptService.ECS.TycoonFactory)

--// Types

type ProfileManagerLike = {
	AddCash: (player: Player, amount: number) -> (),
	AddEmerald: (player: Player, amount: number) -> (),
}

type PurchaseHandler = (player: Player, profileManager: ProfileManagerLike) -> Enum.ProductPurchaseDecision

type TycoonPurchaseTarget = number

type PendingPurchase = {
	tycoon: TycoonPurchaseTarget?,
	button: BasePart?,
	gamepassId: number,
}

--// Constants

local Gamepasses: { [string]: number } = {
	RainbowCarpet = 1568782544,
	X2Cash = 1568972351,
	SWAT_Gamepass = 1573236427,
	Raygun = 1793083522,
	GoldenDropper = 1618227062,
}

local Schedule = function(Delay: number, Callback: () -> (), _Name: string?, _RepeatEvery: number?)
	task.delay(Delay, Callback)
end

local ResolveButtonGamepassId = function(Button: BasePart, GamepassKey: string?): number?
	if GamepassKey then
		return Gamepasses[GamepassKey]
	end

	return Gamepasses[Button.Name]
end

--// Module

local CommerceService = {}
CommerceService.__index = CommerceService

--// Constructor

function CommerceService.new(PlayerService: any): any
	local Self = setmetatable({}, CommerceService)
	Self.PlayerService = PlayerService
	Self.ProfileManager = ProfileManager
	Self.PurchaseHandlers = {} :: { [number]: PurchaseHandler }
	Self.PendingPurchases = setmetatable({}, { __mode = "k" }) :: { [Player]: PendingPurchase }
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
	Players.PlayerRemoving:Connect(function(Player)
		self.PendingPurchases[Player] = nil
	end)
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

--// Internal Methods â€” Setup

function CommerceService:_SetupProductHandlers()
	for ProductId, Handler in ProductRewards do
		self.PurchaseHandlers[ProductId] = Handler
	end
end
local function IsReceiptSaved(Profile, PurchaseId: string): boolean
	local SavedData = Profile.LastSavedData
	if type(SavedData) ~= "table" then
		return false
	end

	local SavedReceipts = SavedData.ProcessedReceipts
	return type(SavedReceipts) == "table" and SavedReceipts[PurchaseId] ~= nil
end

local function WaitForReceiptSave(Profile, PurchaseId: string): boolean
	if IsReceiptSaved(Profile, PurchaseId) then
		return true
	end

	Profile:Save()
	local Deadline = os.clock() + 15
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

function CommerceService:_SetupProcessReceipt()
	MarketplaceService.ProcessReceipt = function(ReceiptInfo)
		local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
		if not Player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local Profile = self.ProfileManager.Profiles[Player]
		if not Profile or not Profile:IsActive() then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local Handler = self.PurchaseHandlers[ReceiptInfo.ProductId]
		if not Handler then
			warn(
				`[CommerceService] No receipt handler exists for product {ReceiptInfo.ProductId} (purchase {tostring(ReceiptInfo.PurchaseId)})`
			)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local PurchaseId = tostring(ReceiptInfo.PurchaseId)
		local Receipts = Profile.Data.ProcessedReceipts
		if Receipts == nil then
			Receipts = {}
			Profile.Data.ProcessedReceipts = Receipts
		elseif type(Receipts) ~= "table" then
			warn(`[CommerceService] Invalid receipt history for {Player.Name}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if Receipts[PurchaseId] == nil then
			local Success, Decision = xpcall(function()
				return Handler(Player, self.ProfileManager)
			end, debug.traceback)
			if not Success then
				warn(`[CommerceService] Receipt {PurchaseId} failed for {Player.Name}:\n{Decision}`)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if Decision ~= Enum.ProductPurchaseDecision.PurchaseGranted then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			Receipts[PurchaseId] = os.time()
		end

		local Success, Saved = xpcall(function()
			return WaitForReceiptSave(Profile, PurchaseId)
		end, debug.traceback)
		if not Success then
			warn(`[CommerceService] Could not save receipt {PurchaseId} for {Player.Name}:\n{Saved}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return if Saved then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
end
function CommerceService:_HandleSWATItemClick(Player: Player, ModelParent: Model, TycoonModel: Model)
	local OwnedTycoon = self.PlayerService:GetTycoon(Player)
	if not OwnedTycoon or TycoonFactory.getModel(OwnedTycoon) ~= TycoonModel then
		return
	end

	if not CollectionService:HasTag(ModelParent, "SWAT Riot") then
		return
	end

	local ownership = self.GamepassCache:GetOwnership(Player, Gamepasses.SWAT_Gamepass)
	if ownership == nil then
		local success, result = pcall(function()
			return self.GamepassCache:Refresh(Player, Gamepasses.SWAT_Gamepass)
		end)
		if not success then
			warn(`[CommerceService] SWAT ownership check failed for {Player.Name}: {result}`)
			return
		end
		ownership = result
	end
	if ownership == nil or Player.Parent ~= Players then
		return
	end
	if not ownership then
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

	local Ownership = self.GamepassCache:GetOwnership(Player, GamepassId)
	if Ownership == nil then
		local Success, Result = pcall(function()
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
		TycoonRuntime.applyPurchasedButton(Tycoon, Button)
	end

	self.PendingPurchases[Player] = nil
end

return CommerceService

