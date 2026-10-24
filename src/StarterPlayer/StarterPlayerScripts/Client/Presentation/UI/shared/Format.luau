--!strict

local Format = {}

function Format.compactNumber(value: number): string
	local absolute = math.abs(value)
	if absolute >= 1_000_000_000 then
		return string.format("%.1fB", value / 1_000_000_000)
	elseif absolute >= 1_000_000 then
		return string.format("%.1fM", value / 1_000_000)
	elseif absolute >= 10_000 then
		return string.format("%.1fK", value / 1_000)
	end

	local rounded = math.floor(value)
	local text = tostring(rounded)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end

	return formatted
end

function Format.currency(value: number): string
	return "$" .. Format.compactNumber(value)
end

return Format
