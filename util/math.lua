-- util/math.lua
--
-- Utility functions for mathematical operations.

local Math = {}

function Math.clamp(value, min_value, max_value)
	if value < min_value then
		return min_value
	end
	if value > max_value then
		return max_value
	end
	return value
end

function Math.lerp(a, b, t)
	return a + (b - a) * t
end

function Math.length(x, y)
	return math.sqrt(x * x + y * y)
end

function Math.distance(x1, y1, x2, y2)
	return Math.length(x2 - x1, y2 - y1)
end

function Math.normalize(x, y)
	local len = Math.length(x, y)
	if len == 0 then
		return 0, 0
	end
	return x / len, y / len
end

return Math
