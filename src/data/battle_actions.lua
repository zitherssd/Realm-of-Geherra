local CombatFormulas = require("src.game.util.CombatFormulas")
local ui = require("src.game.battle.BattleUI")
local grid = require("src.game.battle.BattleGrid")

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
                    local dist = math.abs(otherUnit.currentCell.x - unit.currentCell.x) +
                        math.abs(otherUnit.currentCell.y - unit.currentCell.y)
                    if dist < closestDist then
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

            if(unit:distToTarget(target) > self.range) then
                return {
                    valid = false,
                    reason = "not_in_range"
                }
            end

            return {
                valid = true,
                target = target,
                action = self
            }
        end,

        execute = function(self, unit, target, battleState)
        
            if not target then return end
            if(unit:distToTarget(target) > self.range) then return end
            local attacker = self
            local defender = target
            
            if defender.currentCell.x > attacker.currentCell.x then
                attacker.facing_right = true
            elseif defender.currentCell.x < attacker.currentCell.x then
                attacker.facing_right = false
            end

            attacker:flash({ 1, 1, 1 }, 0.1)
            local roll = love.math.random(1, 100)
            local hit = roll <= CombatFormulas:calculateHitChance(attacker, defender)

            if hit then
                defender.target = attacker
                local damage = CombatFormulas:calculateDamage(attacker, defender)
                ui:createDamagePopup(defender.battle_x, defender.battle_y, damage)
                defender:flash({ 1, 0, 0 }, 0.25)
                defender.health = defender.health - damage
            else
                defender:shake(0.2, 1)
            end

            if defender.health <= 0 then
                grid:removeUnitFromCell(defender, defender.currentCell)
            end
        end
    },
    unarmed_attack = {
        name = "Unarmed Attack",
        description = "A basic attack with your fists.",
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
                    local dist = math.abs(otherUnit.currentCell.x - unit.currentCell.x) +
                        math.abs(otherUnit.currentCell.y - unit.currentCell.y)
                    if dist < closestDist then
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

            if(unit:distToTarget(target) > self.range) then
                return {
                    valid = false,
                    reason = "not_in_range"
                }
            end

            return {
                valid = true,
                target = target,
                action = self
            }
        end,

        execute = function(self, unit, target, battleState)

            if not target then return end
            if(unit:distToTarget(target) > self.range) then return end
            local attacker = self
            local defender = target
            
            if defender.currentCell.x > attacker.currentCell.x then
                attacker.facing_right = true
            elseif defender.currentCell.x < attacker.currentCell.x then
                attacker.facing_right = false
            end

            attacker:flash({ 1, 1, 1 }, 0.1)
            local roll = love.math.random(1, 100)
            local hit = roll <= CombatFormulas:calculateHitChance(attacker, defender)

            if hit then
                defender.target = attacker
                local damage = CombatFormulas:calculateDamage(attacker, defender)
                ui:createDamagePopup(defender.battle_x, defender.battle_y, damage)
                defender:flash({ 1, 0, 0 }, 0.25)
                defender.health = defender.health - damage
            else
                defender:shake(0.2, 1)
            end

            if defender.health <= 0 then
                grid:removeUnitFromCell(defender, defender.currentCell)
            end
        end
    },
    dragon_breath = {
        name = "Dragon Breath",
        description = "A fiery breath attack.",
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
                    local dist = math.abs(otherUnit.currentCell.x - unit.currentCell.x) +
                        math.abs(otherUnit.currentCell.y - unit.currentCell.y)
                    if dist < closestDist then
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

            if(unit:distToTarget(target) > self.range) then
                return {
                    valid = false,
                    reason = "not_in_range"
                }
            end

            return {
                valid = true,
                target = target,
                action = self
            }
        end,

        execute = function(self, unit, target, battleState)

            if not target then return end
            if(unit:distToTarget(target) > self.range) then return end
            local attacker = self
            local defender = target
            
            if defender.currentCell.x > attacker.currentCell.x then
                attacker.facing_right = true
            elseif defender.currentCell.x < attacker.currentCell.x then
                attacker.facing_right = false
            end

            attacker:flash({ 1, 1, 1 }, 0.1)
            local roll = love.math.random(1, 100)
            local hit = roll <= CombatFormulas:calculateHitChance(attacker, defender)

            if hit then
                defender.target = attacker
                local damage = CombatFormulas:calculateDamage(attacker, defender)
                ui:createDamagePopup(defender.battle_x, defender.battle_y, damage)
                defender:flash({ 1, 0, 0 }, 0.25)
                defender.health = defender.health - damage
            else
                defender:shake(0.2, 1)
            end

            if defender.health <= 0 then
                grid:removeUnitFromCell(defender, defender.currentCell)
            end
        end
    },
    -- Do not attempt to implement this yet
    bow_arrow_fire = {
        range = 10,
        cooldownStart = 30,
        cooldownEnd = 30,
        execute = function(unit, battleState)
            -- Here there should be code for spawning arrow
        end,
        try = function(unit, battleState)
            -- looks if there is target in range
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

function actions:unarmed_attack(overrides)
    return self:create("unarmed_attack", overrides)
end

function actions:dragon_breath(overrides)
    return self:create("dragon_breath", overrides)
end

return actions