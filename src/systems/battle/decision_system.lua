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
    local Squads = require("src.game.battle.squads")
    local position = Squads.position(unit)
    local target, distance = context.findNearestHostile(unit)
    local rangedRange, best, priority = nil, nil, -math.huge
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
                local range = RangeUtils.effectiveSkillRange(unit, target, skill)
                local score = (ranged and 1000 or 0) + (skill.baseDamage or 0)
                if distance <= range^2 and (not rangedRange or ranged) and score > priority then
                    best, priority = id, score
                end
            end
        end
    end
    if best then
        local skill = CombatSystem.getEffectiveSkill(unit, best)
        unit.intent = {type="SKILL", skillId=best, targetUnitId=target.id,
            target=skill.targeted and {x=target.x,y=target.y} or nil}
    elseif position then
        if (unit.x-position.x)^2 + (unit.y-position.y)^2 > 12^2 then
            unit.intent = {type="MOVE", target=position, avoidObstacles=true}
        end
    elseif target and (not rangedRange or distance > rangedRange^2) then
        unit.intent = {type="MOVE", target={x=target.x,y=target.y}, avoidObstacles=true}
    end
end

return DecisionSystem
