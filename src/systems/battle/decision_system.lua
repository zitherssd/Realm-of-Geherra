local Projectile = require("src.game.battle.projectiles")
-- systems/battle/decision_system.lua
-- Determines intents for AI and processes Player commands
-- Executed once per battle tick (20Hz) by a BattleSimulation instance.

local Concord = require("src.libs.concord")
local CombatSystem = require("src.systems.battle.combat_system")
local RangeUtils = require("src.systems.battle.range_utils")
local BattleUnitSystem = require("src.systems.battle.battle_unit_system")

local DecisionSystem = Concord.system({pool = {"battleUnit"}})

function DecisionSystem:update(context)
    local units = self.pool
    local playerCommand = context.data.playerCommand

    for _, unit in ipairs(units) do
        if BattleUnitSystem.canAct(unit) and unit.intent == nil then
            
            if unit.fleeing then
                unit.intent = {type="MOVE", target={x=unit.escapeEdge, y=unit.y}, avoidObstacles=true}
            elseif unit.id == context.data.selectedUnitId then
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
    local Squads = require("src.game.battle.squads")
    local position = Squads.position(unit)
    local wasRegrouping = unit.regrouping
    if position then
        local offsetSq = (unit.x-position.x)^2+(unit.y-position.y)^2
        unit.regrouping = offsetSq > 24^2 or (wasRegrouping and offsetSq > 12^2) or false
    else
        unit.regrouping = false
    end
    if not unit.regrouping then unit.regroupAttack = nil end
    local target, distance = context.findNearestHostile(unit)
    local rangedRange, best, priority = nil, nil, -math.huge
    local bestTarget, bestRisk, bestDistance
    -- Cooldown affects readiness, never whether ranged supplies remain viable.
    for id in pairs(unit.skills or {}) do
        local skill = CombatSystem.getEffectiveSkill(unit, id)
        if skill and skill.type ~= "command" and not skill.healing and
            (not skill.maxCharges or (unit.charges[id] or 0) > 0) then
            local ranged = skill.type == "ranged" or skill.projectile or (skill.range or 0) > 2
            local range = RangeUtils.effectiveSkillRange(unit, target, skill)
            if ranged then rangedRange = math.max(rangedRange or 0, range) end
        end
    end
    if target then
        for id in pairs(unit.skills or {}) do
            local skill = CombatSystem.getEffectiveSkill(unit, id)
            if skill and skill.type ~= "command" and not skill.healing and
                (not skill.maxCharges or (unit.charges[id] or 0) > 0) and
                (unit.cooldowns[id] or 0) <= 0 then
                local ranged = skill.type == "ranged" or skill.projectile or (skill.range or 0) > 2
                local score = (ranged and 1000 or 0) + (skill.baseDamage or 0)
                for _, candidate in ipairs(context.data.unitList) do
                    if candidate.team ~= unit.team and candidate.hp > 0 and not candidate.escaped then
                        local d = (candidate.x-unit.x)^2+(candidate.y-unit.y)^2
                        local range = RangeUtils.effectiveSkillRange(unit, candidate, skill)
                        local risk = 0
                        -- A nil risk vetoes launch obstruction, but melee exposure only ranks targets.
                        if skill.projectile then risk = Projectile.friendlyRisk(unit,candidate,skill,context) end
                        if risk and d <= range^2 and (not rangedRange or ranged) and
                            (score > priority or (score == priority and
                                (risk < bestRisk or (risk == bestRisk and d < bestDistance)))) then
                            best, priority, bestTarget, bestRisk, bestDistance = id, score, candidate, risk, d
                        end
                    end
                end
            end
        end
    end
    if unit.regrouping then
        local previousGoal = unit.moveTarget
        local blocked = wasRegrouping and previousGoal and previousGoal.x==position.x and previousGoal.y==position.y
            and (unit.velocityX or 0)^2+(unit.velocityY or 0)^2 < 2^2
        -- A blocked regroup attempt may trade one attack, then must retry movement.
        if not (blocked and best and not unit.regroupAttack) then
            unit.intent = {type="MOVE", target=position, avoidObstacles=true}
            unit.regroupAttack = nil
            return
        end
        unit.regroupAttack = true
    end
    if best then
        target = bestTarget
        local skill = CombatSystem.getEffectiveSkill(unit, best)
        unit.intent = {type="SKILL", skillId=best, targetUnitId=target.id,
            target=skill.targeted and {x=target.x,y=target.y} or nil}
    elseif not position and target and (not rangedRange or distance > rangedRange^2) then
        unit.intent = {type="MOVE", target={x=target.x,y=target.y}, avoidObstacles=true}
    end
end

return DecisionSystem
