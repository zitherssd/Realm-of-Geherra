local gridActions = require("src.game.battle.BattleGridActions")
local grid = require("src.game.battle.BattleGrid")
local BattleUnitAI = {
    battle = nil
}

function BattleUnitAI:unitTick(unit, battleState)
    -- Cooldown
    if unit.action_cooldown > 0 then
        unit.action_cooldown = unit.action_cooldown - 1
    end

    -- Execute pending action if ready
    if unit.pending_action and unit.action_cooldown <= 0 then
        if unit.pending_action.execute then
            unit.pending_action:execute(unit, unit.pending_action.target, battleState)
            unit.pending_action.executed_tick = battleState.currentTick
            unit.action_cooldown = unit.pending_action.cooldownEnd or 50
        end
        unit.pending_action = nil
        return
    end

    -- Decide new action if possible
    if not unit.pending_action and unit.action_cooldown <= 0 then
        -- Player units are handled by BattlePlayerInput, so we don't decide for them
        if unit.controllable and unit == self.battle.playerUnit then
            return
        end

        -- AI decision logic
        local availableActions = unit:getActions()

        self:updateTarget(unit, battleState)

        for _, action in ipairs(availableActions) do
            local success, reason = gridActions:tryUseAction(unit, action, battleState)
            if success or reason == "moved" then
                return
            end
        end
    end
end

function BattleUnitAI:updateTarget(unit, battleState)
    -- 1. Check if current battle_target is alive
    if unit.battle_target and (unit.battle_target.health <= 0 or not unit.battle_target.currentCell) then
        unit.battle_target = nil
    end

    -- 2. Check nearby 8 grids for closer targets (preference for front)
    if unit.currentCell then
        local currentDist = math.huge
        if unit.battle_target and unit.battle_target.currentCell then
            currentDist = grid:getDistance(unit.currentCell, unit.battle_target.currentCell)
        end

        -- Only switch if we find someone closer (dist 1) than current target (dist > 1)
        -- or if we have no target
        if currentDist > 1 then
            local bestNeighbor = nil
            local bestScore = -1
            local cx, cy = unit.currentCell.x, unit.currentCell.y
            local dirX = unit.facing_right and 1 or -1
            
            -- Offsets with preference scores
            local offsets = {
                {x=dirX, y=0, s=10},   -- Front
                {x=dirX, y=-1, s=8},   -- Front-Up
                {x=dirX, y=1, s=8},    -- Front-Down
                {x=0, y=-1, s=5},      -- Up
                {x=0, y=1, s=5},       -- Down
                {x=-dirX, y=-1, s=2},  -- Back-Up
                {x=-dirX, y=1, s=2},   -- Back-Down
                {x=-dirX, y=0, s=1}    -- Back
            }

            for _, off in ipairs(offsets) do
                local nx, ny = cx + off.x, cy + off.y
                if grid:isValidPosition(nx, ny) then
                    local cell = grid.cells[nx][ny]
                    for _, u in ipairs(cell.units) do
                        if u.battle_party ~= unit.battle_party and u.health > 0 then
                            if off.s > bestScore then
                                bestScore = off.s
                                bestNeighbor = u
                            end
                        end
                    end
                end
            end

            if bestNeighbor then
                unit.battle_target = bestNeighbor
            end
        end
    end

    -- 3. Fallback: Find closest enemy if still no target
    if not unit.battle_target then
        local enemies = {}
        for _, u in ipairs(battleState.units) do
            if u.battle_party ~= unit.battle_party and u.health > 0 and u.currentCell then
                table.insert(enemies, u)
            end
        end

        if #enemies > 0 then
            -- Count how many allies are targeting each enemy
            local targetCounts = {}
            for _, ally in ipairs(battleState.units) do
                if ally.battle_party == unit.battle_party and ally ~= unit and ally.battle_target then
                    targetCounts[ally.battle_target] = (targetCounts[ally.battle_target] or 0) + 1
                end
            end

            -- Pre-calculate distances for sorting
            local distances = {}
            for _, e in ipairs(enemies) do
                distances[e] = grid:getDistance(unit.currentCell, e.currentCell)
            end

            -- Prefer nearest enemy with lowest target count
            table.sort(enemies, function(a, b)
                local ca = targetCounts[a] or 0
                local cb = targetCounts[b] or 0
                if ca ~= cb then return ca < cb end
                return distances[a] < distances[b]
            end)

            unit.battle_target = enemies[1]
        end
    end
end

function BattleUnitAI:updateTargetProjectile(unit, action, battleState)
    local range = action.range
    if not range then return end

    local currentTarget = unit.battle_target
    local currentDist = math.huge

    -- Calculate distance to current target if it exists
    if currentTarget and currentTarget.health > 0 and currentTarget.currentCell and unit.currentCell then
        currentDist = grid:getEuclideanDistance(unit.currentCell, currentTarget.currentCell)
    end

    -- If current target is out of range (or invalid), look for another target that IS in range
    if currentDist > range then
        local bestTarget = nil
        local closestDist = math.huge

        for _, candidate in ipairs(battleState.units) do
            if candidate.battle_party ~= unit.battle_party and candidate.health > 0 and candidate.currentCell and unit.currentCell then
                local d = grid:getEuclideanDistance(unit.currentCell, candidate.currentCell)
                if d <= range and d < closestDist then
                    closestDist = d
                    bestTarget = candidate
                end
            end
        end

        if bestTarget then
            unit.battle_target = bestTarget
        end
    end
end

function BattleUnitAI:init(battle)
    self.battle = battle
end

return BattleUnitAI
