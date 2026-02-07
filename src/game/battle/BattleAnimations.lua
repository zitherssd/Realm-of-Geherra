local BattleAnimations = {
    MOVEMENT_DURATION = 0.3,
    CELL_RADIUS = 12,
    HIT_FLASH_DURATION = 0.25
}
local grid = require("src.game.battle.BattleGrid")

function BattleAnimations:updateAnimation(dt, units)
    -- 1. Collect active cells for physics update
    local activeCells = {}
    for _, unit in ipairs(units) do
        if unit.currentCell then
            activeCells[unit.currentCell] = true
        end
    end

    -- 2. Run physics/flocking for all occupied cells (continuous update)
    for cell, _ in pairs(activeCells) do
        self:updateUnitPositionsInCell(cell)
    end

    -- 3. Apply movement and visual effects
    for _, unit in ipairs(units) do
        
        -- Movement: Tween if moving between cells, otherwise slide to subcell position
        if unit.animating then
            unit.animation_timer = unit.animation_timer + dt
            local progress = math.min(1, unit.animation_timer / unit.animation_duration)
            progress = progress * progress * (3 - 2 * progress)
            
            -- Update target in case subcell physics shifted it
            local targetX = unit.desired_x or unit.battle_animation_target_x
            local targetY = unit.desired_y or unit.battle_animation_target_y
            
            unit.battle_x = unit.battle_animation_start_x + (targetX - unit.battle_animation_start_x) * progress
            unit.battle_y = unit.battle_animation_start_y + (targetY - unit.battle_animation_start_y) * progress
            if progress >= 1 then
                unit.animating = false
            end
        elseif unit.desired_x then
            -- Continuous slide (jostling/lunging within cell)
            local speed = 10 * dt
            unit.battle_x = unit.battle_x + (unit.desired_x - unit.battle_x) * speed
            unit.battle_y = unit.battle_y + (unit.desired_y - unit.battle_y) * speed
        end

        local v = unit.visuals

        -- Lunge animation (Visual)
        if v.lunge_duration and v.lunge_timer < v.lunge_duration then
            v.lunge_timer = v.lunge_timer + dt
            local progress = v.lunge_timer / v.lunge_duration
            if progress > 1 then progress = 1 end
            -- Sine wave 0->1->0
            local weight = math.sin(progress * math.pi)
            v.lunge_offset_x = (v.lunge_vec_x or 0) * weight
            v.lunge_offset_y = (v.lunge_vec_y or 0) * weight
        else
            v.lunge_offset_x = 0
            v.lunge_offset_y = 0
        end
        
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

        -- Accumulate repulsion forces to avoid sequential update bias (rotation)
        local pushes = {}
        for i = 1, #units do pushes[i] = {x=0, y=0} end

        -- repel pairs
        for i = 1, #units do
            local ui = units[i]
            for j = i + 1, #units do
                local uj = units[j]
                local dx = ui.subcell_x - uj.subcell_x
                local dy = ui.subcell_y - uj.subcell_y
                local dist2 = dx*dx + dy*dy
                
                -- Prevent division by zero / stacking
                --if dist2 < 0.001 then
                --    dx = (love.math.random() - 0.5) * 0.1
                --    dy = (love.math.random() - 0.5) * 0.1
                --    dist2 = dx*dx + dy*dy
                --end

                local dist = math.sqrt(dist2)
                local overlap = repelDist - dist
                if overlap > 0 then
                    local push = overlap / dist * repelStrength
                    local px = dx * push
                    local py = dy * push
                    
                    pushes[i].x = pushes[i].x + px
                    pushes[i].y = pushes[i].y + py
                    pushes[j].x = pushes[j].x - px
                    pushes[j].y = pushes[j].y - py
                end
            end
        end

        -- Apply accumulated forces
        for i, u in ipairs(units) do
            u.subcell_x = u.subcell_x + pushes[i].x
            u.subcell_y = u.subcell_y + pushes[i].y
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

        -- Calculate desired pixel position
        u.desired_x = cx + u.subcell_x
        u.desired_y = cy + u.subcell_y

        -- Only trigger a full grid-movement tween if the unit is far away (e.g. just placed or moved cells)
        local distToDest = math.sqrt((u.battle_x - u.desired_x)^2 + (u.battle_y - u.desired_y)^2)
        if distToDest > self.CELL_RADIUS * 2 and not u.animating then
            u.battle_animation_start_x = u.battle_x
            u.battle_animation_start_y = u.battle_y
            u.battle_animation_target_x = u.desired_x
            u.battle_animation_target_y = u.desired_y
            u.animating = true
            u.animation_timer = 0
            u.animation_duration = self.MOVEMENT_DURATION
        end
    end
    
end

function BattleAnimations:drawUnits(units)
    table.sort(units, function(a,b) return a.battle_y < b.battle_y end)
end

function BattleAnimations:triggerLunge(unit, target)
    if not unit or not target then return end
    local dx = target.battle_x - unit.battle_x
    local dy = target.battle_y - unit.battle_y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 0 then
        unit.visuals.lunge_vec_x = (dx / dist) * 10 -- 10 pixels lunge
        unit.visuals.lunge_vec_y = (dy / dist) * 10
        unit.visuals.lunge_timer = 0
        unit.visuals.lunge_duration = 0.2 -- fast lunge
    end
end

return BattleAnimations
