local CombatFormulas = require("src.game.util.CombatFormulas")
local ui = require("src.game.battle.BattleUI")
local grid = require("src.game.battle.BattleGrid")
local animations = require("src.game.battle.BattleAnimations")
local assetManager = require("src.game.util.AssetManager")

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
    -- This is not fully implemented yet, starting point
    ranged_attack = {
        range = 5,
        cooldownStart = 25,
        cooldownEnd = 25,
        projectile_sprite = "projectiles/spear.png",
        damage = 5,
        arc_height = 60,
        

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
            
            -- Create Projectile
            local startX, startY = unit.battle_x, unit.battle_y - 20
            local targetCell = target.currentCell
            local targetX, targetY = grid:getCellCenterPixel(targetCell)
            
            local projectile = {
                sprite = assetManager:loadImage(self.projectile_sprite),
                x = startX, y = startY,
                startX = startX, startY = startY,
                targetX = targetX, targetY = targetY,
                targetCell = targetCell, -- Remember where we aimed
                attacker = unit,
                originalTarget = target,
                timer = 0,
                duration = 0.6, -- Flight time in seconds
                arcHeight = self.a, -- Pixel height of the arc

                update = function(p, dt, state)
                    p.timer = p.timer + dt
                    local t = p.timer / p.duration
                    if t >= 1 then t = 1 end

                    -- Linear interpolation
                    local cx = p.startX + (p.targetX - p.startX) * t
                    local cy = p.startY + (p.targetY - p.startY) * t
                    
                    -- Parabolic arc: 4 * h * t * (1-t)
                    local arc = 4 * p.arcHeight * t * (1 - t)
                    p.x = cx
                    p.y = cy - arc

                    -- Calculate rotation (tangent of the curve)
                    local dx = p.targetX - p.startX
                    local dy_linear = p.targetY - p.startY
                    local dy_arc = 4 * p.arcHeight * (1 - 2 * t)
                    local dy = dy_linear - dy_arc
                    p.rotation = math.atan2(dy, dx)

                    if t >= 1 then
                        p:onHit(state)
                        return true -- Remove projectile
                    end
                    return false
                end,

                draw = function(p)
                    if p.sprite then
                        love.graphics.draw(p.sprite, p.x, p.y, p.rotation, 1, 1, p.sprite:getWidth()/2, p.sprite:getHeight()/2)
                    end
                end,

                onHit = function(p, state)
                    -- Check who is in the cell now
                    local unitsInCell = grid:getUnitsInCell(p.targetCell)
                    if #unitsInCell == 0 then return end -- Missed everyone

                    -- Try to hit original target, otherwise pick random unit in cell
                    local hitTarget = nil
                    for _, u in ipairs(unitsInCell) do
                        if u == p.originalTarget then hitTarget = u break end
                    end
                    if not hitTarget then
                        hitTarget = unitsInCell[love.math.random(#unitsInCell)]
                    end

                    -- Don't hit allies
                    if hitTarget.battle_party == p.attacker.battle_party then return end

                    -- Calculate Hit
                    local roll = love.math.random(1, 100)
                    local chance = CombatFormulas:calculateHitChance(p.attacker, hitTarget)
                    
                    -- Bonus accuracy if cell is crowded (density check)
                    if p.targetCell.total_size > (p.targetCell.max_size * 0.5) then
                        chance = chance + 10
                    end

                    if roll <= chance then
                        if not hitTarget.battle_target or grid:getDistance(hitTarget.currentCell, hitTarget.battle_target.currentCell) > 1 then
                            hitTarget.battle_target = p.attacker
                        end
                        local damage = CombatFormulas:calculateDamage(p.attacker, hitTarget)
                        ui:createDamagePopup(hitTarget.battle_x, hitTarget.battle_y, damage)
                        hitTarget:flash({ 1, 0, 0 }, 0.4)
                        hitTarget.health = hitTarget.health - damage
                        if hitTarget.health <= 0 then
                            grid:removeUnitFromCell(hitTarget, hitTarget.currentCell)
                        end
                    else
                        hitTarget:shake(0.4, 1.5)
                        ui:createDamagePopup(hitTarget.battle_x, hitTarget.battle_y, "Miss")
                    end
                end
            }
            
            table.insert(battleState.projectiles, projectile)
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

function actions:ranged_attack(overrides)
    return self:create("ranged_attack", overrides)
end

return actions