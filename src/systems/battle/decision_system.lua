local Conditions = require("src.systems.actors.conditions")
local Projectile = require("src.game.battle.projectiles")
-- systems/battle/decision_system.lua
-- Determines intents for AI and processes Player commands
-- Executed once per battle tick (20Hz) by a BattleSimulation instance.

local Concord = require("src.libs.concord")
local CombatSystem = require("src.systems.battle.combat_system")
local RangeUtils = require("src.systems.battle.range_utils")
local BattleUnitSystem = require("src.systems.battle.battle_unit_system")
local Aoe = require("src.game.battle.aoe")

local DecisionSystem = Concord.system({pool = {"battleUnit"}})

function DecisionSystem:update(context)
    local units = self.pool
    local playerCommand = context.data.playerCommand

    for _, unit in ipairs(units) do
        if BattleUnitSystem.canAct(unit) and unit.intent == nil then
            
            if unit.fleeing then
                if Conditions.permits(unit, "move") then
                    unit.intent = {type="MOVE", target={x=unit.escapeEdge, y=unit.y}, avoidObstacles=true}
                end
            elseif unit.id == context.data.selectedUnitId then
                -- Player Logic: Check for command
                if playerCommand and playerCommand.unitId == unit.id then
                    unit.intent = {
                        type = playerCommand.type,
                        target = playerCommand.target,
                        skillId = playerCommand.skillId,
                        targetUnitId = playerCommand.targetUnitId,
                        targetDirection = playerCommand.targetDirection
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
    if not Conditions.permits(unit, "attack") and not Conditions.permits(unit, "move") and not Conditions.permits(unit, "cast") then return end
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
    local bestTarget, bestRisk, bestDistance, bestAoePlacement
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
    do
        for id in pairs(unit.skills or {}) do
            local skill = CombatSystem.getEffectiveSkill(unit, id)
            if skill and skill.type ~= "command" and (skill.aoe or not skill.healing) and
                (not skill.maxCharges or (unit.charges[id] or 0) > 0) and
                (unit.cooldowns[id] or 0) <= 0 then
                local ranged = skill.type == "ranged" or skill.projectile or (skill.range or 0) > 2
                local score = (ranged and 1000 or 0) + (skill.baseDamage or 0)
                if skill.aoe then
                    local mode = Aoe.targetingMode(skill.aoe, skill)
                    local beneficial = (skill.healing ~= nil and skill.healing ~= false) or skill.aoe.eligibility == "allies"
                    local bestPlacement, bestPlacementScore, useful = nil, 0, 0
                    for _, candidate in ipairs(context.data.unitList) do
                        local appropriate = (candidate.team == unit.team) == beneficial
                        if candidate.hp > 0 and not candidate.escaped and appropriate then
                            local px, py = mode == "self" and unit.x or candidate.x,
                                mode == "self" and unit.y or candidate.y
                            local distanceSq = (px-unit.x)^2+(py-unit.y)^2
                            if mode ~= "ground" or distanceSq <= RangeUtils.effectiveSkillRange(unit, nil, skill)^2 then
                                local shape = Aoe.at(unit, skill.aoe, px, py)
                                local hits = Aoe.select(shape, context.data.unitList, unit, skill.aoe.eligibility)
                                local good, friendly = 0, 0
                                for _, hit in ipairs(hits) do
                                    if (hit.team == unit.team) == beneficial and
                                        (not skill.healing or hit.hp < hit.maxHp) then good = good+1
                                    elseif not beneficial then friendly = friendly+1 end
                                end
                                local placementScore = good-friendly*2
                                if good > useful or (good == useful and placementScore > bestPlacementScore) then
                                    useful, bestPlacementScore = good, placementScore
                                    bestPlacement = {x=px,y=py,dx=px-unit.x,dy=py-unit.y}
                                end
                            end
                        end
                    end
                    if bestPlacement and useful > 0 and bestPlacementScore > 0 then
                        score = score + bestPlacementScore*10
                        if score > priority then
                            best, priority, bestTarget, bestRisk, bestDistance = id, score, nil, 0, 0
                            bestAoePlacement = {
                                point = mode == "direction" and {x=unit.x,y=unit.y} or {x=bestPlacement.x,y=bestPlacement.y},
                                direction = mode == "direction" and {x=bestPlacement.dx,y=bestPlacement.dy} or nil
                            }
                        end
                    end
                elseif target then for _, candidate in ipairs(context.data.unitList) do
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
                end end
            end
        end
    end
    if unit.regrouping and Conditions.permits(unit, "move") then
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
        local skill = CombatSystem.getEffectiveSkill(unit, best)
        if skill.aoe then
            local placement = bestAoePlacement
            unit.intent = {type="SKILL", skillId=best, target=placement.point, targetDirection=placement.direction}
        else
            target = bestTarget
            unit.intent = {type="SKILL", skillId=best, targetUnitId=target.id,
                target=skill.targeted and {x=target.x,y=target.y} or nil}
        end
    elseif Conditions.permits(unit, "move") and not position and target and (not rangedRange or distance > rangedRange^2) then
        unit.intent = {type="MOVE", target={x=target.x,y=target.y}, avoidObstacles=true}
    end
end

return DecisionSystem
