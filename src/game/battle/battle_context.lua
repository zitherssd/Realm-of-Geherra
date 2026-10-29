-- Per-instance blackboard for the current battle simulation.

local BattleContext = {}

function BattleContext.new(bounds)
    local context = {}

    context.data = {
        units = {},
        unitList = {},
        bounds = {
            width = (bounds and bounds.width) or 1260,
            height = (bounds and bounds.height) or 546
        },
        playerUnit = nil,
        paused = false,
        playerCommand = nil,
        selectedUnitId = nil,
        outcome = nil,
        tick = 0,
        accumulator = 0,
        selectedSkillIndex = 1,
        inputCooldown = 0,
        targetingMode = false,
        targetingSkillId = nil,
        targetingPoint = nil,
        camera = {x = 0, y = 0, zoom = 1.3},
        debug = {
            showCollisionCircles = true
        },
        floatingTexts = {},
        projectiles = {},
        vfx = {},
        casualties = {}
    }

    function context.addUnit(battleUnit)
        if not battleUnit then return end
        local r = battleUnit.collisionRadius or 0
        local bounds = context.data.bounds
        battleUnit.x = math.max(r, math.min(bounds.width - r, battleUnit.x))
        battleUnit.y = math.max(r, math.min(bounds.height - r, battleUnit.y))
        context.data.units[battleUnit.id] = battleUnit
        table.insert(context.data.unitList, battleUnit)
    end

    function context.removeDeadUnits()
        local units = context.data.unitList

        for i = #units, 1, -1 do
            local unit = units[i]
            if unit.hp <= 0 then
                table.insert(context.data.casualties, unit)
                context.data.units[unit.id] = nil
                table.remove(units, i)
                unit:destroy()
            end
        end
    end

    function context.addFloatingText(x, y, text, color, centered)
        table.insert(context.data.floatingTexts, {
            x = x,
            y = y,
            text = text,
            color = color or {1, 1, 1, 1},
            time = 0,
            duration = 1.0,
            offsetY = 0,
            centered = centered or false
        })
    end

    function context.addProjectile(projectile)
        table.insert(context.data.projectiles, projectile)
    end

    function context.addVfx(effect)
        table.insert(context.data.vfx, effect)
    end

    function context.findNearestHostile(unit, maxRange)
        local nearestTarget = nil
        local minDist = math.huge
        local maxRangeSq = maxRange and (maxRange * maxRange) or math.huge

        for _, other in ipairs(context.data.unitList) do
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

    return context
end

return BattleContext
