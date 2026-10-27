--!strict
-- Big numbers stored as log10 values. 0 is represented by Num.ZERO.
-- Multiplication is addition; addition uses the log-sum trick.

local Num = {}

Num.ZERO = -1e9

function Num.fromNumber(x: number): number
	if x <= 0 then
		return Num.ZERO
	end
	return math.log10(x)
end

function Num.toNumber(l: number): number
	if l <= Num.ZERO then
		return 0
	end
	return 10 ^ l
end

function Num.isZero(l: number): boolean
	return l <= Num.ZERO + 1
end

function Num.add(a: number, b: number): number
	if Num.isZero(a) then
		return b
	end
	if Num.isZero(b) then
		return a
	end
	local hi, lo = math.max(a, b), math.min(a, b)
	if hi - lo > 15 then
		return hi
	end
	return hi + math.log10(1 + 10 ^ (lo - hi))
end

-- a - b, clamped at zero
function Num.sub(a: number, b: number): number
	if Num.isZero(b) then
		return a
	end
	if b >= a then
		return Num.ZERO
	end
	if a - b > 15 then
		return a
	end
	return a + math.log10(1 - 10 ^ (b - a))
end

function Num.mul(a: number, b: number): number
	if Num.isZero(a) or Num.isZero(b) then
		return Num.ZERO
	end
	return a + b
end

-- multiply a log value by a plain number factor
function Num.scale(a: number, factor: number): number
	if factor <= 0 or Num.isZero(a) then
		return Num.ZERO
	end
	return a + math.log10(factor)
end

-- a log value multiplied by a plain count, e.g. Applause for n claps
function Num.times(a: number, n: number): number
	return Num.scale(a, n)
end

function Num.gte(a: number, b: number): boolean
	return a >= b - 1e-9
end

return Num
