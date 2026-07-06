--!strict

local Rarity = {}

export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

local RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
}

local KEYWORD_RULES = {
	{
		rarity = "Legendary" :: ItemRarity,
		keywords = { "legendary", "mythic", "mythical", "divine", "gold", "golden", "raygun" },
	},
	{
		rarity = "Epic" :: ItemRarity,
		keywords = { "epic", "plasma", "laser", "railgun", "rocket", "rpg", "minigun" },
	},
	{
		rarity = "Rare" :: ItemRarity,
		keywords = { "rare", "sniper", "scar", "ak", "m4", "rifle", "shotgun", "lmg" },
	},
	{
		rarity = "Uncommon" :: ItemRarity,
		keywords = { "uncommon", "smg", "uzi", "mp5", "grenade", "armor", "medkit", "kit" },
	},
}

local CATEGORY_RULES = {
	Weapon = { "gun", "rifle", "pistol", "shotgun", "sniper", "smg", "ak", "m4", "scar", "laser", "rpg", "rocket", "sword", "knife" },
	Explosive = { "grenade", "charge", "c4", "rocket", "rpg" },
	Utility = { "kit", "armor", "med", "heal", "wrench", "tool" },
}

local ACCENT_BY_RARITY: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 198, 210),
	Uncommon = Color3.fromRGB(92, 225, 152),
	Rare = Color3.fromRGB(94, 174, 255),
	Epic = Color3.fromRGB(187, 116, 255),
	Legendary = Color3.fromRGB(255, 174, 74),
}

local function normalize(value: any): string
	if typeof(value) ~= "string" then
		return ""
	end

	return string.lower(value)
end

local function hasKeyword(text: string, keywords: { string }): boolean
	for _, keyword in ipairs(keywords) do
		if string.find(text, keyword, 1, true) then
			return true
		end
	end

	return false
end

local function validRarity(value: any): ItemRarity?
	if typeof(value) == "string" and RARITY_ORDER[value] then
		return value :: ItemRarity
	end

	return nil
end

function Rarity.getColor(rarity: ItemRarity): Color3
	return ACCENT_BY_RARITY[rarity] or ACCENT_BY_RARITY.Common
end

function Rarity.classifyTool(tool: Tool): ItemRarity
	local explicit = validRarity(tool:GetAttribute("Rarity"))
	if explicit then
		return explicit
	end

	local score = tool:GetAttribute("RarityScore")
	if typeof(score) == "number" then
		if score >= 95 then
			return "Legendary"
		elseif score >= 80 then
			return "Epic"
		elseif score >= 55 then
			return "Rare"
		elseif score >= 30 then
			return "Uncommon"
		end

		return "Common"
	end

	local searchable = normalize(tool.Name)
	local displayName = tool:GetAttribute("DisplayName")
	if typeof(displayName) == "string" then
		searchable ..= " " .. normalize(displayName)
	end

	for _, rule in ipairs(KEYWORD_RULES) do
		if hasKeyword(searchable, rule.keywords) then
			return rule.rarity
		end
	end

	if tool:FindFirstChild("ACS_Settings") then
		return "Rare"
	end

	return "Common"
end

function Rarity.classifyCategory(tool: Tool): string
	local explicit = tool:GetAttribute("Category")
	if typeof(explicit) == "string" and explicit ~= "" then
		return explicit
	end

	if tool:FindFirstChild("ACS_Settings") then
		return "Weapon"
	end

	local searchable = normalize(tool.Name)
	for category, keywords in pairs(CATEGORY_RULES) do
		if hasKeyword(searchable, keywords) then
			return category
		end
	end

	return "Tool"
end

function Rarity.getAccent(tool: Tool, rarity: ItemRarity): Color3
	local explicit = tool:GetAttribute("AccentColor")
	if typeof(explicit) == "Color3" then
		return explicit
	end

	return Rarity.getColor(rarity)
end

return Rarity
