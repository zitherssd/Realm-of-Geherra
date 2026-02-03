local BattleAnimations = {
    MOVEMENT_DURATION = 0.3,
    CELL_RADIUS = 12,
    HIT_FLASH_DURATION = 0.25
}
local grid = require("src.game.battle.BattleGrid")

function BattleAnimations:updateAnimation(dt, units)
    for _, unit in ipairs(units) do
        
        -- Movement animation
        if unit.animating then
            unit.animation_timer = unit.animation_timer + dt
            local progress = math.min(1, unit.animation_timer / unit.animation_duration)
            progress = progress * progress * (3 - 2 * progress)
            unit.battle_x = unit.battle_animation_start_x + (unit.battle_animation_target_x - unit.battle_animation_start_x) * progress
            unit.battle_y = unit.battle_animation_start_y + (unit.battle_animation_target_y - unit.battle_animation_start_y) * progress
            if progress >= 1 then
                unit.animating = false
            end
        end

        local v = unit.visuals

        -- Flash fade
        if v.flash_timer and v.flash_timer > 0 then
            v.flash_timer = v.flash_timer - dt
            local t = math.max(0, v.flash_timer / (v.flash_duration or 0.001))
            v.flash_alpha = t
        else
            v.flash_alpha = 0
        end

        -- Shake decay
        if v.shake_time and v.shake_time > 0 then
            v.shake_time = v.shake_time - dt
            v.shake_intensity = v.shake_intensity * (1 - dt * 10)
            if v.shake_time <= 0 then
                v.shake_time = 0
                v.shake_intensity = 0
            end
        end
    end
end

function BattleAnimations:updateUnitPositionsInCell(cell)
    local units = grid:getUnitsInCell(cell)
    local cx, cy = grid:getCellCenterPixel(cell)
    if #units == 0 then return end

    local radius = self.CELL_RADIUS * 1
    local repelDist = radius * 1.2
    local stiffness = 0.2        -- pull to center
    local repelStrength = 0.6    -- how strong they push away
    local relaxIterations = 5

    -- --- Step 1: initialize subcell positions if new ---
    for _, u in ipairs(units) do
        if not u.subcell_x then
            -- enter roughly from where the unit came from
            local dx, dy = u.battle_x - cx, u.battle_y - cy
            local len = math.sqrt(dx*dx + dy*dy)
            if len > 0 then dx, dy = dx/len, dy/len else dx, dy = 0, -1 end
            u.subcell_x = dx * radius * 0.6
            u.subcell_y = dy * radius * 0.6
        end
    end

    -- --- Step 2: relax positions ---
    for _ = 1, relaxIterations do
        -- pull each unit slightly toward center
        for _, u in ipairs(units) do
            u.subcell_x = u.subcell_x - u.subcell_x * stiffness
            u.subcell_y = u.subcell_y - u.subcell_y * stiffness
        end

        -- repel pairs
        for i = 1, #units do
            local ui = units[i]
            for j = i + 1, #units do
                local uj = units[j]
                local dx = ui.subcell_x - uj.subcell_x
                local dy = ui.subcell_y - uj.subcell_y
                local dist2 = dx*dx + dy*dy
                if dist2 > 0 then
                    local dist = math.sqrt(dist2)
                    local overlap = repelDist - dist
                    if overlap > 0 then
                        local push = overlap / dist * repelStrength
                        dx, dy = dx * push, dy * push
                        ui.subcell_x = ui.subcell_x + dx
                        ui.subcell_y = ui.subcell_y + dy
                        uj.subcell_x = uj.subcell_x - dx
                        uj.subcell_y = uj.subcell_y - dy
                    end
                end
            end
        end
    end

    -- --- Step 3: clamp within cell radius ---
    for _, u in ipairs(units) do
        local dx, dy = u.subcell_x, u.subcell_y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > radius then
            u.subcell_x = dx / dist * radius
            u.subcell_y = dy / dist * radius
        end

        -- Animate toward actual pixel position
        u.battle_animation_start_x = u.battle_x
        u.battle_animation_start_y = u.battle_y
        u.battle_animation_target_x = cx + u.subcell_x
        u.battle_animation_target_y = cy + u.subcell_y
        u.animating = true
        u.animation_timer = 0
        u.animation_duration = self.MOVEMENT_DURATION
    end
end

function BattleAnimations:drawUnits(units)
    table.sort(units, function(a,b) return a.battle_y < b.battle_y end)
end


return BattleAnimations
