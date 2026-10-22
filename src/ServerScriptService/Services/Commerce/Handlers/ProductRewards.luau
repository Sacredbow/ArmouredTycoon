--!strict

const GearDistribution = require(script.Parent.GearDistribution)

type ProfileManagerLike = {
	AddCash: (Player: Player, Amount: number) -> (),
	AddEmerald: (Player: Player, Amount: number) -> (),
}

type RewardHandler = (Player: Player, ProfileManager: ProfileManagerLike) -> Enum.ProductPurchaseDecision

const ProductIds = {
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
	[ProductIds.Cash_5000] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddCash(Player, 5000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Cash_25000] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddCash(Player, 25000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Cash_50000] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddCash(Player, 50000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Cash_250000] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddCash(Player, 250000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Cash_500000] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddCash(Player, 500000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Emerald_300] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddEmerald(Player, 300)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Emerald_750] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddEmerald(Player, 750)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Emerald_1250] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddEmerald(Player, 1250)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Emerald_3500] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddEmerald(Player, 3500)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.Emerald_10000] = function(Player: Player, ProfileManager: ProfileManagerLike)
		ProfileManager.AddEmerald(Player, 10000)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
	[ProductIds.ShieldArmour] = function(Player: Player, _ProfileManager: ProfileManagerLike)
		if not GearDistribution.GiveShield(Player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end,
} :: { [number]: RewardHandler }