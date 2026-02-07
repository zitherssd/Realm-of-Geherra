local CombatFormulas = require("src.game.util.CombatFormulas")
local ui = require("src.game.battle.BattleUI")
local grid = require("src.game.battle.BattleGrid")
local animations = require("src.game.battle.BattleAnimations")

local actionTemplates = {
    melee_attack = {
        range = 1,
        cooldownStart = 25,
        cooldownEnd = 25,

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
    ranged_attack = {
        range = 5,
        cooldownStart = 25,
        cooldownEnd = 25,
        projectile_sprite = "assets/sprites/projectiles/arrow/spear.png",
        damage = 5,

        try = function(self, unit, battleState)
            -- 
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
            
            -- Here it would spawn a projectile and handle it separately with its own hit logic 

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
    }
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