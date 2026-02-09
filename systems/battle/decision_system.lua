-- systems/battle/decision_system.lua
-- Determines intents for AI and processes Player commands

local DecisionSystem = {}

function DecisionSystem.update(dt, context)
    local units = context.data.unitList
    local grid = context.data.grid
    local playerCommand = context.data.playerCommand

    for _, unit in ipairs(units) do
        if unit:canAct() and unit.intent == nil then
            
            if unit.team == "player" then
                -- Player Logic: Check for command
                if playerCommand and playerCommand.unitId == unit.id then
                    unit.intent = {
                        type = playerCommand.type,
                        target = playerCommand.target
                    }
                    -- Consume command after assignment
                    context.data.playerCommand = nil
                end
                
            elseif unit.team == "enemy" then
                -- AI Logic: Simple Aggro
                DecisionSystem._processAI(unit, context)
            end
        end
    end
end

function DecisionSystem._processAI(unit, context)
    -- Find nearest hostile
    local nearestTarget = nil
    local minDist = math.huge

    for _, other in ipairs(context.data.unitList) do
        if other.team ~= unit.team and other.hp > 0 then
            local dx = unit.x - other.x
            local dy = unit.y - other.y
            local dist = dx*dx + dy*dy
            if dist < minDist then
                minDist = dist
                nearestTarget = other
            end
        end
    end

    if nearestTarget then
        -- If adjacent, attack (placeholder for skill logic)
        if minDist <= 2 then -- sqrt(2) is diagonal, so <= 2 covers adjacency
            unit.intent = {
                type = "SKILL",
                skillId = "slash",
                targetUnitId = nearestTarget.id
            }
        else
            -- Move towards target
            -- Very dumb pathfinding: just move one step closer
            -- In real impl, use A* here or in a pathfinding utility
        end
    end
end

return DecisionSystem