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
        local closest = nil
        local minDist = math.huge
        for _, u in ipairs(battleState.units) do
            if u.battle_party ~= unit.battle_party and u.health > 0 and u.currentCell and unit.currentCell then
                local d = grid:getDistance(unit.currentCell, u.currentCell)
                if d < minDist then
                    minDist = d
                    closest = u
                end
            end
        end
        unit.battle_target = closest
    end
end

function BattleUnitAI:init(battle)
    self.battle = battle
end

return BattleUnitAI
