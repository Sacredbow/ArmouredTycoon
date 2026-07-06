--!strict

local ItemIconRegistry = {}

local ICON_BY_NAME: { [string]: string } = {
	["glock19x (9mm)"] = "",
	glock19x = "",
	ak47 = "",
	m4a1 = "",
	scar = "",
	sniper = "",
	shotgun = "",
	smg = "",
}

local function normalizeName(name: string): string
	return string.lower(name):gsub("[%s%p_]+", "")
end

local function toAssetImage(assetId: string): string?
	if assetId == "" then
		return nil
	end

	if string.find(assetId, "rbxassetid://", 1, true) or string.find(assetId, "rbxthumb://", 1, true) then
		return assetId
	end

	return `rbxassetid://{assetId}`
end

function ItemIconRegistry.getIcon(tool: Tool): string?
	local exact = ICON_BY_NAME[string.lower(tool.Name)]
	if exact then
		return toAssetImage(exact)
	end

	local normalizedToolName = normalizeName(tool.Name)
	for name, assetId in pairs(ICON_BY_NAME) do
		if normalizeName(name) == normalizedToolName then
			return toAssetImage(assetId)
		end
	end

	return nil
end

return ItemIconRegistry
