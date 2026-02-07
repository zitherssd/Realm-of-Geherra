local CombatFormulas = require("src.game.util.CombatFormulas")
local ui = require("src.game.battle.BattleUI")
local grid = require("src.game.battle.BattleGrid")
local animations = require("src.game.battle.BattleAnimations")

local actionTemplates = {
    melee_attack = {
        range = 1,
        cooldownStart = 25,
        cooldownEnd = 25,

        getTarget = function(unit, battleState)
            local closestDist = math.huge
            local closestUnit = nil
            local oppositeParty = nil

            if (unit.battle_party == 1) then
                oppositeParty = battleState.enemyParty
            else
                oppositeParty = battleState.playerParty
            end

            for _, otherUnit in ipairs(oppositeParty.units) do
                if otherUnit.health > 0 then
                    local dist = grid:getDistance(unit.currentCell, otherUnit.currentCell)
                    
                    local isBetter = false
                    if dist < closestDist then
                        isBetter = true
                    elseif dist == closestDist and closestUnit then
                        -- Tie-breaker: Prioritize unit we are facing
                        local dxCurrent = otherUnit.currentCell.x - unit.currentCell.x
                        local dxBest = closestUnit.currentCell.x - unit.currentCell.x
                        
                        -- If facing right, prefer targets to the right (dx > 0)
                        if unit.facing_right and dxCurrent > dxBest then isBetter = true end
                        if not unit.facing_right and dxCurrent < dxBest then isBetter = true end
                    end

                    if isBetter then
                        closestDist = dist
                        closestUnit = otherUnit
                    end
                end
            end
            return closestUnit
        end,

        try = function(self, unit, battleState)
            local target = unit.battle_target
            if not target then
                return {
                    valid = false,
                    reason = "no_target"
                }
            end

            if grid:getDistance(unit.currentCell, target.currentCell) > self.range then
                return {
                    valid = false,
                    reason = "not_in_range"
                }
            end
            unit:flash({ 1, 1, 1 }, 0.3)

            return {
                

                valid = true,
                target = target,
                action = self
            }
        end,

        execute = function(self, unit, target, battleState)
        
            if not target then return end
            if not unit.currentCell or not target.currentCell or grid:getDistance(unit.currentCell, target.currentCell) > self.range then return end
            local attacker = unit
            local defender = target
            
            if defender.currentCell.x > attacker.currentCell.x then
                attacker.facing_right = true
            elseif defender.currentCell.x < attacker.currentCell.x then
                attacker.facing_right = false
            end
            
            animations:triggerLunge(attacker, defender)

            local roll = love.math.random(1, 100)
            local hit = roll <= CombatFormulas:calculateHitChance(attacker, defender)

            if hit then
                if not defender.battle_target or grid:getDistance(defender.currentCell, defender.battle_target.currentCell) > 1 then
                    defender.battle_target = attacker
                end
                local damage = CombatFormulas:calculateDamage(attacker, defender)
                ui:createDamagePopup(defender.battle_x, defender.battle_y, damage)
                defender:flash({ 1, 0, 0 }, 0.4)
                defender.health = defender.health - damage
            else
                defender:shake(0.4, 1.5)
            end

            if defender.health <= 0 then
                grid:removeUnitFromCell(defender, defender.currentCell)
            end
        end
    },
}
local actions = {}

function actions:create(actionId, overrides)
    local template = actionTemplates[actionId]
    if not template then
        error("Unknown action template: " .. tostring(actionId))
    end

    local newAction = {}
    -- Copy template properties and methods
    for k, v in pairs(template) do
        newAction[k] = v
    end

    -- Apply overrides
    if overrides then
        for k, v in pairs(overrides) do
            newAction[k] = v
        end
    end

    return newAction
end

function actions:melee_attack(overrides)
    return self:create("melee_attack", overrides)
end

return actions