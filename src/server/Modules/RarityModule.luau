local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoxFolder = ReplicatedStorage:WaitForChild("BoxFolder")

local RarityModule = {}

local Boxes = {
	["Common"] = BoxFolder.Common;
	["Rare"] = BoxFolder.Rare;
	["Legendary"] = BoxFolder.Legendary;
	["Mythical"] = BoxFolder.Mythical;
	["Divine"] = BoxFolder.Divine;
	
}

local Rarities = {
	["Common"] = 49;
	["Rare"] = 30;
	["Legendary"] = 16;
	["Mythical"] = 4;
	["Divine"] = 1
}


function RarityModule:SpawnRandomBox()
	local randomNumber = math.random(1, 100)
	local counter = 0
	
	for rarity, weight in Rarities do
		counter += weight
		
		if counter >= randomNumber then
			return Boxes[rarity]
		end
		
	end
	return Boxes["Common"]

end

return RarityModule
