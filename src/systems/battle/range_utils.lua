-- systems/battle/range_utils.lua
-- Shared range helpers for the battle systems.

local RangeUtils = {}

RangeUtils.WORLD_RANGE_SCALE = 42

-- Effective reach in world units: skill range scaled to world space plus both
-- units' collision radii.
function RangeUtils.effectiveSkillRange(attacker, target, skillData)
    local baseRange = ((skillData and skillData.range) or 1.5) * RangeUtils.WORLD_RANGE_SCALE
    if skillData and skillData.aoe then return baseRange end
    local attackerRadius = attacker.collisionRadius or 0
    local targetRadius = (target and target.collisionRadius) or 0
    return baseRange + attackerRadius + targetRadius
end

return RangeUtils
