--!strict
-- Number formatting for HUD and captions.

local Num = require(script.Parent.Num)

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trim(n: number): string
	if n >= 100 then
		return string.format("%d", math.floor(n))
	end
	return (string.format("%.1f", math.floor(n * 10) / 10):gsub("%.0$", ""))
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end
Format.commas = commas

-- Format a log10 value with K/M/B suffixes, then scientific.
function Format.short(l: number): string
	if Num.isZero(l) then
		return "0"
	end
	if l < 3 then
		local n = 10 ^ l
		if n < 10 then
			return trim(n)
		end
		return tostring(math.floor(n + 1e-6))
	end
	local group = math.floor(l / 3 + 1e-9)
	if group < #SUFFIXES then
		local mantissa = 10 ^ (l - group * 3)
		return trim(mantissa) .. SUFFIXES[group + 1]
	end
	local e = math.floor(l + 1e-9)
	return string.format("%.2fe%d", 10 ^ (l - e), e)
end

-- Plain number (not log) with suffixes
function Format.number(n: number): string
	return Format.short(Num.fromNumber(n))
end

-- Japanese 万 / 億 / 兆 / 京 style (flavour captions)
local JP = { { 16, "京" }, { 12, "兆" }, { 8, "億" }, { 4, "万" } }
function Format.japanese(l: number): string
	for _, pair in JP do
		if l >= pair[1] then
			local v = 10 ^ (l - pair[1])
			return trim(v) .. pair[2]
		end
	end
	return commas(10 ^ l)
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
