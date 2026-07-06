local NumberModule = {}

local abbreviations = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg", "Uvg"}

function NumberModule.abbreviateNumber(num)
	if num < 1000 then
		return tostring(num)
	end

	local i = 0
	while num >= 1000 and i < #abbreviations - 1 do
		num = num / 1000
		i = i + 1
	end

	if num % 1 == 0 then
		return string.format("%d%s", num, abbreviations[i+1])
	else
		return string.format("%.1f%s", num, abbreviations[i+1])
	end
end


return NumberModule