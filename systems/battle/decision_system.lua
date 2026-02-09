-- systems/battle/decision_system.lua
-- Determines intents for AI and processes Player commands
-- Executed once per battle tick (20Hz)

local DecisionSystem = {}
local Skills = require("data.skills")

function DecisionSystem.update(context)
    local units = context.data.unitList
    local grid = context.data.grid
    local playerCommand = context.data.playerCommand

    for _, unit in ipairs(units) do
        if unit:canAct() and unit.intent == nil then
            
            if unit.id == context.data.selectedUnitId then
                -- Player Logic: Check for command
                if playerCommand and playerCommand.unitId == unit.id then
                    unit.intent = {
                        type = playerCommand.type,
                        target = playerCommand.target
                    }
                    -- Consume command after assignment
                    context.data.playerCommand = nil
                end
                
            else
                -- AI Logic: Simple Aggro (for Enemies AND Allies)
                DecisionSystem._processAI(unit, context)
            end
        end
    end
end

function DecisionSystem._processAI(unit, context)
    local grid = context.data.grid
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
        -- AI Logic: Select best available skill from actor's known skills
        local bestSkillId = nil
        local bestPriority = -1
        
        -- Iterate through all skills the actor knows
        for skillId, _ in pairs(unit.skills or {}) do
            local skillData = Skills[skillId]
            
            if skillData then
                local rangeSq = skillData.range * skillData.range
                local onCooldown = (unit.cooldowns[skillId] or 0) > 0
                local hasCharges = true
                
                -- Check charges if the skill has a limit
                if skillData.maxCharges then
                    hasCharges = (unit.charges[skillId] or 0) > 0
                end
                
                -- Check if usable (in range and off cooldown)
                if not onCooldown and hasCharges and minDist <= rangeSq then
                    -- Priority: Prefer higher damage multiplier
                    local priority = skillData.damageMultiplier or 0
                    
                    if priority > bestPriority then
                        bestPriority = priority
                        bestSkillId = skillId
                    end
                end
            end
        end
        
        if bestSkillId then
            unit.intent = {
                type = "SKILL",
                skillId = bestSkillId,
                targetUnitId = nearestTarget.id
            }
        else
            -- Move towards target
            local neighbors = grid:getNeighbors(unit.x, unit.y)
            local bestMove = nil
            local bestDist = minDist

            for _, cell in ipairs(neighbors) do
                if grid:isFree(cell.x, cell.y) then
                    local dx = cell.x - nearestTarget.x
                    local dy = cell.y - nearestTarget.y
                    local d = dx*dx + dy*dy
                    if d < bestDist then
                        bestDist = d
                        bestMove = cell
                    end
                end
            end

            if bestMove then
                unit.intent = {
                    type = "MOVE",
                    target = {x = bestMove.x, y = bestMove.y}
                }
            end
        end
    end
end

return DecisionSystem