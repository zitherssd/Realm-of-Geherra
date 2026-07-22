-- game/battle/battle_context.lua
-- Shared blackboard for the current battle instance.

local BattleContext = {}

BattleContext.data = {
    units = {},          -- Map of ID -> BattleUnit
    unitList = {},       -- Ordered list for iteration
    bounds = {width = 1260, height = 546},

    -- Time management
    paused = false,

    -- Input / Command
    playerCommand = nil,

    -- Selection
    selectedUnitId = nil,

    -- State
    outcome = nil,       -- nil, "win", "loss", "flee"

    -- Tick system
    tick = 0,
    accumulator = 0,

    -- Camera + effects
    camera = {x = 0, y = 0, zoom = 1.3},
    debug = {
        showCollisionCircles = true
    },
    floatingTexts = {},
    projectiles = {},
    vfx = {},
    casualties = {}
}

function BattleContext.init(bounds)
    BattleContext.data.units = {}
    BattleContext.data.unitList = {}
    BattleContext.data.bounds = {
        width = (bounds and bounds.width) or 1260,
        height = (bounds and bounds.height) or 546
    }
    BattleContext.data.paused = false
    BattleContext.data.playerCommand = nil
    BattleContext.data.selectedUnitId = nil
    BattleContext.data.outcome = nil
    BattleContext.data.tick = 0
    BattleContext.data.accumulator = 0
    BattleContext.data.selectedSkillIndex = 1
    BattleContext.data.inputCooldown = 0
    BattleContext.data.targetingMode = false
    BattleContext.data.targetingSkillId = nil
    BattleContext.data.targetingPoint = nil
    BattleContext.data.camera = {x = 0, y = 0, zoom = 1.3}
    BattleContext.data.debug = {
        showCollisionCircles = true
    }
    BattleContext.data.floatingTexts = {}
    BattleContext.data.projectiles = {}
    BattleContext.data.vfx = {}
    BattleContext.data.casualties = {}
end

function BattleContext.addUnit(battleUnit)
    if not battleUnit then return end
    BattleContext.data.units[battleUnit.id] = battleUnit
    table.insert(BattleContext.data.unitList, battleUnit)
end

function BattleContext.removeDeadUnits()
    local units = BattleContext.data.unitList

    for i = #units, 1, -1 do
        local unit = units[i]
        if unit.hp <= 0 then
            table.insert(BattleContext.data.casualties, unit)
            BattleContext.data.units[unit.id] = nil
            table.remove(units, i)
        end
    end
end

function BattleContext.addFloatingText(x, y, text, color)
    table.insert(BattleContext.data.floatingTexts, {
        x = x,
        y = y,
        text = text,
        color = color or {1, 1, 1, 1},
        time = 0,
        duration = 1.0,
        offsetY = 0
    })
end

function BattleContext.addProjectile(proj)
    table.insert(BattleContext.data.projectiles, proj)
end

function BattleContext.addVfx(effect)
    table.insert(BattleContext.data.vfx, effect)
end

function BattleContext.findNearestHostile(unit, maxRange)
    local nearestTarget = nil
    local minDist = math.huge
    local maxRangeSq = maxRange and (maxRange * maxRange) or math.huge

    for _, other in ipairs(BattleContext.data.unitList) do
        if other.team ~= unit.team and other.hp > 0 then
            local dx = unit.x - other.x
            local dy = unit.y - other.y
            local distSq = dx * dx + dy * dy

            if distSq <= maxRangeSq + 0.01 and distSq < minDist then
                minDist = distSq
                nearestTarget = other
            end
        end
    end

    return nearestTarget, minDist
end

return BattleContext