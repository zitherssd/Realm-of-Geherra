local CombatFormulas = require("src.game.util.CombatFormulas")
local ui = require("src.game.battle.BattleUI")
local grid = require("src.game.battle.BattleGrid")
local animations = require("src.game.battle.BattleAnimations")
local assetManager = require("src.game.util.AssetManager")
local BattleUnitAI = require("src.game.battle.BattleUnitAI")

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
        range = 8,
        cooldownStart = 25,
        cooldownEnd = 25,
        projectile_sprite = "projectiles/spear.png",
        projectile_speed = 600,
        damage = 5,
        arc_height = 35,
        projectile_count = 1,
        ammo = nil,
        max_ammo = 8,
        

        try = function(self, unit, battleState)
            if self.max_ammo and self.ammo and self.ammo <= 0 then
                return { valid = false, reason = "no_ammo" }
            end

            BattleUnitAI:updateTargetProjectile(unit, self, battleState) -- Ensure we have an updated target before trying
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
            
            if self.max_ammo and self.ammo then
                self.ammo = self.ammo - 1
            end

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

            local dx = targetX - startX
            local dy = targetY - startY
            local dist = math.sqrt(dx*dx + dy*dy)
            local speed = self.projectile_speed or 600
            
            -- Scale arc height based on distance (flatter at close range)
            local maxDistPixels = self.range * grid.GRID_SIZE
            local scaledArcHeight = (self.arc_height or 0) * math.min(1, dist / maxDistPixels)
            
            local projectile = {
                sprite = assetManager:loadImage(self.projectile_sprite),
                x = startX, y = startY,
                startX = startX, startY = startY,
                targetX = targetX, targetY = targetY,
                targetCell = targetCell, -- Remember where we aimed
                attacker = unit,
                originalTarget = target,
                timer = 0,
                duration = math.max(0.1, dist / speed), -- Flight time based on speed
                arcHeight = scaledArcHeight, -- Pixel height of the arc

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

                    -- Calculate Hit Chance based on density
                    local cell = p.targetCell
                    local density = cell.total_size / cell.max_size
                    local hitChance = math.min(100, density * 100)
                    local roll = love.math.random(1, 100)

                    if roll <= hitChance then
                        -- Hit confirmed: Pick random unit in cell
                        local hitTarget = unitsInCell[love.math.random(#unitsInCell)]
                        
                        if hitTarget.battle_party ~= p.attacker.battle_party then
                            if not hitTarget.battle_target or grid:getDistance(hitTarget.currentCell, hitTarget.battle_target.currentCell) > 1 then
                                hitTarget.battle_target = p.attacker
                            end
                        end
                        
                        local damage = CombatFormulas:calculateDamage(p.attacker, hitTarget)
                        ui:createDamagePopup(hitTarget.battle_x, hitTarget.battle_y, damage)
                        hitTarget:flash({ 1, 0, 0 }, 0.4)
                        hitTarget.health = hitTarget.health - damage
                        if hitTarget.health <= 0 then
                            grid:removeUnitFromCell(hitTarget, hitTarget.currentCell)
                        end
                    else
                        -- Missed the cell contents entirely
                        local cx, cy = grid:getCellCenterPixel(p.targetCell)
                        ui:createDamagePopup(cx, cy, "Miss")
                    end
                end
            }
            
            table.insert(battleState.projectiles, projectile)
        end
    },
    area_attack = {
        range = 6,
        cooldownStart = 30,
        cooldownEnd = 30,
        projectile_sprite = "projectiles/spear.png", -- Placeholder, ideally fireball
        projectile_speed = 600,
        damage = 8,
        arc_height = 0, -- Flat trajectory by default
        aoe_radius = 0, -- 0 = single cell, 1 = 3x3 area

        try = function(self, unit, battleState)
            local target = unit.battle_target
            if not target then return { valid = false, reason = "no_target" } end

            if grid:getDistance(unit.currentCell, target.currentCell) > self.range then
                return { valid = false, reason = "not_in_range" }
            end
            unit:flash({ 1, 0.5, 0 }, 0.3)

            return { valid = true, target = target, action = self }
        end,

        execute = function(self, unit, target, battleState)
            if not target or not unit.currentCell or not target.currentCell then return end
            
            -- Face target
            if target.currentCell.x > unit.currentCell.x then unit.facing_right = true
            elseif target.currentCell.x < unit.currentCell.x then unit.facing_right = false end
            
            local startX, startY = unit.battle_x, unit.battle_y - 20
            local targetCell = target.currentCell
            local targetX, targetY = grid:getCellCenterPixel(targetCell)

            local dx = targetX - startX
            local dy = targetY - startY
            local dist = math.sqrt(dx*dx + dy*dy)
            local speed = self.projectile_speed or 600
            
            -- Scale arc height based on distance
            local maxDistPixels = self.range * grid.GRID_SIZE
            local scaledArcHeight = (self.arc_height or 0) * math.min(1, dist / maxDistPixels)
            
            local projectile = {
                sprite = assetManager:loadImage(self.projectile_sprite),
                x = startX, y = startY,
                startX = startX, startY = startY,
                targetX = targetX, targetY = targetY,
                targetCell = targetCell,
                attacker = unit,
                timer = 0,
                duration = math.max(0.1, dist / speed),
                arcHeight = scaledArcHeight,
                aoeRadius = self.aoe_radius,

                update = function(p, dt, state)
                    p.timer = p.timer + dt
                    local t = p.timer / p.duration
                    if t >= 1 then t = 1 end

                    local cx = p.startX + (p.targetX - p.startX) * t
                    local cy = p.startY + (p.targetY - p.startY) * t
                    local arc = 4 * p.arcHeight * t * (1 - t)
                    p.x = cx
                    p.y = cy - arc

                    local dx = p.targetX - p.startX
                    local dy_linear = p.targetY - p.startY
                    local dy_arc = 4 * p.arcHeight * (1 - 2 * t)
                    p.rotation = math.atan2(dy_linear - dy_arc, dx)

                    if t >= 1 then
                        p:onHit(state)
                        return true
                    end
                    return false
                end,

                draw = function(p)
                    if p.sprite then
                        love.graphics.draw(p.sprite, p.x, p.y, p.rotation, 1, 1, p.sprite:getWidth()/2, p.sprite:getHeight()/2)
                    end
                end,

                onHit = function(p, state)
                    local cellsToCheck = { p.targetCell }
                    -- Add neighbors if radius > 0
                    if p.aoeRadius > 0 then
                        local cx, cy = p.targetCell.x, p.targetCell.y
                        for dx = -p.aoeRadius, p.aoeRadius do
                            for dy = -p.aoeRadius, p.aoeRadius do
                                if grid:isValidPosition(cx + dx, cy + dy) and not (dx==0 and dy==0) then
                                    table.insert(cellsToCheck, grid.cells[cx+dx][cy+dy])
                                end
                            end
                        end
                    end

                    for _, cell in ipairs(cellsToCheck) do
                        for _, u in ipairs(cell.units) do
                            if u.battle_party ~= p.attacker.battle_party then
                                local damage = CombatFormulas:calculateDamage(p.attacker, u)
                                ui:createDamagePopup(u.battle_x, u.battle_y, damage)
                                u:flash({ 1, 0.2, 0 }, 0.4)
                                u.health = u.health - damage
                                if u.health <= 0 then
                                    grid:removeUnitFromCell(u, u.currentCell)
                                end
                            end
                        end
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

    -- Initialize ammo if max_ammo is defined but ammo is not
    if newAction.max_ammo and newAction.ammo == nil then
        newAction.ammo = newAction.max_ammo
    end

    return newAction
end

function actions:melee_attack(overrides)
    return self:create("melee_attack", overrides)
end

function actions:ranged_attack(overrides)
    return self:create("ranged_attack", overrides)
end

function actions:area_attack(overrides)
    return self:create("area_attack", overrides)
end

return actions