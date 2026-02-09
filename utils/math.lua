-- utils/math.lua
-- Math utility functions

local Math = {}

function Math.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function Math.angle(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

function Math.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Math.lerp(start, finish, t)
    return start + (finish - start) * t
end

function Math.normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length == 0 then
        return 0, 0
    end
    return x / length, y / length
end

return Math
