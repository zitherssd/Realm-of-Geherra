-- ecs/systems/decision_system.lua
-- Determines intents for AI and processes Player commands
-- Executed once per battle tick (20Hz) via EcsWorld.battle:emit("update", ...)

local Concord = require("src.libs.concord")
local Skills = require("src.data.skills")
local RangeUtils = require("src.systems.battle.range_utils")
local BattleUnitSystem = require("src.systems.battle.battle_unit_system")

local DecisionSystem = Concord.system({pool = {"battleUnit"}})

function DecisionSystem:update(context)
    local units = self.pool
    local playerCommand = context.data.playerCommand

    for _, unit in ipairs(units) do
        if BattleUnitSystem.canAct(unit) and unit.intent == nil then
            
            if unit.id == context.data.selectedUnitId then
                -- Player Logic: Check for command
                if playerCommand and playerCommand.unitId == unit.id then
                    unit.intent = {
                        type = playerCommand.type,
                        target = playerCommand.target,
                        skillId = playerCommand.skillId,
                        targetUnitId = playerCommand.targetUnitId
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
    -- Find nearest hostile
    local nearestTarget, minDist = context.findNearestHostile(unit)

    if nearestTarget then
        -- AI Logic: Select best available skill from actor's known skills
        local bestSkillId = nil
        local bestPriority = -1
        
        -- Iterate through all skills the actor knows
        for skillId, _ in pairs(unit.skills or {}) do
            local skillData = Skills[skillId]
            
            if skillData then
                local range = RangeUtils.effectiveSkillRange(unit, nearestTarget, skillData)
                local rangeSq = range * range
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
            local bestSkillData = Skills[bestSkillId]
            local intentTarget = nil
            local intentTargetUnitId = nearestTarget.id

            if bestSkillData and bestSkillData.type == "aoe" and bestSkillData.targeted == true then
                intentTarget = {x = nearestTarget.x, y = nearestTarget.y}
            end

            unit.intent = {
                type = "SKILL",
                skillId = bestSkillId,
                target = intentTarget,
                targetUnitId = intentTargetUnitId
            }
        else
            unit.intent = {
                type = "MOVE",
                target = {x = nearestTarget.x, y = nearestTarget.y}
            }
        end
    end
end

return DecisionSystem