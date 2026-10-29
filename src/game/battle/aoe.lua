-- Battlefield X/Y shapes; all dimensions are world units, cone angle is radians.
local Aoe = {}
local EPSILON = 1e-9

function Aoe.targetingMode(config, skill)
    if config.targeting then return config.targeting end
    if config.shape == "circle" then
        if not skill or (skill.range or 0) == 0 then return "self" end
        return "ground"
    end
    return "direction"
end

local function segmentDistanceSquared(x, y, ax, ay, bx, by)
    local dx, dy = bx-ax, by-ay
    local lengthSq = dx*dx+dy*dy
    local t = lengthSq > 0 and math.max(0, math.min(1, ((x-ax)*dx+(y-ay)*dy)/lengthSq)) or 0
    return (x-ax-t*dx)^2+(y-ay-t*dy)^2
end

function Aoe.intersects(shape, unit)
    local x, y = unit.x-shape.x, unit.y-shape.y
    local radius = math.max(0, unit.collisionRadius or 0)
    if shape.shape == "circle" then
        return x*x+y*y <= (math.max(0, shape.radius or 0)+radius)^2+EPSILON
    end

    local nx, ny = shape.dx or 0, shape.dy or 0
    local directionLength = math.sqrt(nx*nx+ny*ny)
    if directionLength == 0 then nx, ny = 1, 0 else nx, ny = nx/directionLength, ny/directionLength end
    local length = math.max(0, shape.length or 0)
    if shape.shape == "line" then
        local reach = math.max(0, shape.width or 0)/2+radius
        return segmentDistanceSquared(x,y,0,0,nx*length,ny*length) <= reach*reach+EPSILON
    end

    assert(shape.shape == "cone", "Unknown AoE shape: "..tostring(shape.shape))
    local halfAngle = math.max(0, math.min(2*math.pi, shape.angle or 0))/2
    local distance = math.sqrt(x*x+y*y)
    local insideAngle = distance == 0 or (x*nx+y*ny)/distance >= math.cos(halfAngle)-EPSILON
    -- Inside the angular wedge, the nearest point is on its radial arc (or inside).
    if insideAngle and distance <= length+radius+EPSILON then return true end
    -- Outside the wedge, either radial edge (including its endpoints) is closest.
    local c, s = math.cos(halfAngle), math.sin(halfAngle)
    return math.min(
        segmentDistanceSquared(x,y,0,0,length*(nx*c-ny*s),length*(ny*c+nx*s)),
        segmentDistanceSquared(x,y,0,0,length*(nx*c+ny*s),length*(ny*c-nx*s))
    ) <= radius*radius+EPSILON
end

function Aoe.select(shape, units, caster, eligibility)
    eligibility = eligibility or "all"
    assert(eligibility == "all" or eligibility == "allies" or eligibility == "enemies", "Unknown AoE eligibility")
    local targets, seen = {}, {}
    for _, unit in ipairs(units) do
        if not seen[unit] and unit.hp > 0 and not unit.escaped and Aoe.intersects(shape, unit) then
            seen[unit] = true
            if eligibility == "all" or (eligibility == "allies" and unit.team == caster.team)
                or (eligibility == "enemies" and unit.team ~= caster.team) then
                targets[#targets+1] = unit
            end
        end
    end
    return targets
end

-- A circle follows the selected point; directional shapes originate at the caster,
-- or at an explicit origin. A zero-distance aim uses the caster's facing.
function Aoe.at(caster, config, x, y, directionX, directionY)
    local shape = {}
    for key, value in pairs(config) do shape[key] = value end
    if config.shape == "circle" then
        shape.x, shape.y = x, y
    else
        shape.x, shape.y = caster.x, caster.y
        if config.origin then shape.x, shape.y = config.origin.x, config.origin.y end
        shape.dx, shape.dy = directionX or x-shape.x, directionY or y-shape.y
        if shape.dx == 0 and shape.dy == 0 then shape.dx, shape.dy = -(caster.facing or -1), 0 end
    end
    return shape
end

return Aoe
