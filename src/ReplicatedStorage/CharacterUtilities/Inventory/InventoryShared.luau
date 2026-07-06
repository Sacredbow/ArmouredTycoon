--!strict

local InventoryShared = {}

export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type InventoryItem = {
	id: string,
	name: string,
	category: string,
	rarity: ItemRarity,
	quantity: number,
	slot: number?,
	accent: Color3,
	icon: string?,
	stats: { [string]: number }?,
	equipped: boolean?,
	source: any?,
}

export type InventorySnapshot = {
	items: { InventoryItem },
	selectedSlot: number,
	maxSlots: number,
}

InventoryShared.MAX_SLOTS = 8

InventoryShared.RarityColors = {
	Common = Color3.fromRGB(190, 198, 210),
	Uncommon = Color3.fromRGB(92, 225, 152),
	Rare = Color3.fromRGB(94, 174, 255),
	Epic = Color3.fromRGB(187, 116, 255),
	Legendary = Color3.fromRGB(255, 174, 74),
}

local PLACEHOLDER_ITEMS: { InventoryItem } = {
	{
		id = "primary",
		name = "Primary",
		category = "Weapon",
		rarity = "Rare",
		quantity = 1,
		slot = 1,
		accent = Color3.fromRGB(255, 116, 82),
	},
	{
		id = "sidearm",
		name = "Sidearm",
		category = "Weapon",
		rarity = "Common",
		quantity = 1,
		slot = 2,
		accent = Color3.fromRGB(235, 242, 255),
	},
	{
		id = "armor-kit",
		name = "Armor Kit",
		category = "Utility",
		rarity = "Uncommon",
		quantity = 2,
		slot = 3,
		accent = Color3.fromRGB(93, 232, 170),
	},
	{
		id = "charges",
		name = "Charges",
		category = "Explosive",
		rarity = "Epic",
		quantity = 4,
		slot = 4,
		accent = Color3.fromRGB(255, 198, 82),
	},
}

local function copyItem(item: InventoryItem): InventoryItem
	return {
		id = item.id,
		name = item.name,
		category = item.category,
		rarity = item.rarity,
		quantity = item.quantity,
		slot = item.slot,
		accent = item.accent,
		icon = item.icon,
		stats = item.stats,
		equipped = item.equipped,
		source = item.source,
	}
end

function InventoryShared.createPlaceholderSnapshot(): InventorySnapshot
	local items = table.create(#PLACEHOLDER_ITEMS)
	for index, item in ipairs(PLACEHOLDER_ITEMS) do
		items[index] = copyItem(item)
	end

	return {
		items = items,
		selectedSlot = 1,
		maxSlots = InventoryShared.MAX_SLOTS,
	}
end

return InventoryShared
