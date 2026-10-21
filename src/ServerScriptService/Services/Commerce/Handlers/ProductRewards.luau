--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
local GearDistribution = require(script.Parent.GearDistribution)

type ProfileManagerLike = {
	AddCash: (player: Player, amount: number) -> (),
	AddEmerald: (player: Player, amount: number) -> (),
}

type RewardHandler = (player: Player, profileManager: ProfileManagerLike) -> Enum.ProductPurchaseDecision

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

return {
	[PRODUCT_IDS.Cash_5000] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddCash(player, 5000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Cash_25000] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddCash(player, 25000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Cash_50000] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddCash(player, 50000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Cash_250000] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddCash(player, 250000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Cash_500000] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddCash(player, 500000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Emerald_300] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddEmerald(player, 300)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Emerald_750] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddEmerald(player, 750)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Emerald_1250] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddEmerald(player, 1250)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Emerald_3500] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddEmerald(player, 3500)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.Emerald_10000] = function(player: Player, profileManager: ProfileManagerLike)
		profileManager.AddEmerald(player, 10000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[PRODUCT_IDS.ShieldArmour] = function(player: Player)
		if not GearDistribution.GiveShield(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		PlayerRuntimeState.SetArmourEquipped(player, true)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
} :: { [number]: RewardHandler }
