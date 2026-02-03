local GameState = require("src.game.GameState")

local BattlePlayerInput = {
    battle = nil,
    playerInputCooldown = 0
}
local gridActions = require("src.game.battle.BattleGridActions")

function BattlePlayerInput:keypressed(key)
    if key == 'escape' then
        GameState:pop()
        return
    end

    if self.battle.playerUnit.action_cooldown and self.battle.playerUnit.action_cooldown > 0 then return end
    
    if key == 'space' then 
        return self:TryPlayerUseSelectedAction()
    end

    local playerCellX, playerCellY = self.battle.playerUnit.currentCell.x, self.battle.playerUnit.currentCell.y
    local moved = false
    if key == 'w' then moved = gridActions:moveUnitToCellByXY(self.battle.playerUnit, playerCellX, playerCellY - 1)
    elseif key == 's' then moved = gridActions:moveUnitToCellByXY(self.battle.playerUnit, playerCellX, playerCellY + 1)
    elseif key == 'a' then moved = gridActions:moveUnitToCellByXY(self.battle.playerUnit, playerCellX - 1, playerCellY)
    elseif key == 'd' then moved = gridActions:moveUnitToCellByXY(self.battle.playerUnit, playerCellX + 1, playerCellY)
    end
    if moved then self.playerInputCooldown = 0.1 end
end

function BattlePlayerInput:TryPlayerAttackNear()
    local player = self.battle.playerUnit
    if player.action_cooldown and player.action_cooldown > 0 then
        return false
    end

    local bestTarget = nil
    local bestPriority = -math.huge

    for _, enemy in ipairs(self.battle.enemyParty.units) do
        local dx = enemy.currentCell.x - player.currentCell.x
        local dy = enemy.currentCell.y - player.currentCell.y
        local dist = math.abs(dx) + math.abs(dy)

        if dist <= 2 then
            local priority = 0

            -- Prioritize enemies in front (based on facing direction)
            local facingRight = player.facing_right
            if facingRight and dx > 0 then
                priority = priority + 10
            elseif not facingRight and dx < 0 then
                priority = priority + 10
            end

            -- Prefer same row (horizontal attacks)
            if dy == 0 then
                priority = priority + 5
            end

            -- Slightly less preference for diagonals
            if math.abs(dy) == 1 then
                priority = priority + 2
            end

            -- Slight preference for closer targets
            priority = priority + (2 - dist)

            if priority > bestPriority then
                bestPriority = priority
                bestTarget = enemy
            end
        end
    end

    if bestTarget then
        gridActions:attack(player, bestTarget)
        return true
    end

    return false
end

function BattlePlayerInput:TryPlayerUseSelectedAction()
    local player = self.battle.playerUnit
    if player.action_cooldown and player.action_cooldown > 0 then return false end
    local idx = self.battle.selectedAction or 1
    local actions = player.actions or {}
    local act = actions[idx]
    if not act then return false end
    return gridActions:useAction(player, act, self.battle.currentTick)
end

function BattlePlayerInput:update(dt)
    if  self.playerInputCooldown > 0 then
        self.playerInputCooldown = self.playerInputCooldown - dt
    end
end

function BattlePlayerInput:init(battle)
    self.battle = battle
end

return BattlePlayerInput