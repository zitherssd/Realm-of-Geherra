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

function BattlePlayerInput:TryPlayerUseSelectedAction()
    local player = self.battle.playerUnit
    if player.action_cooldown and player.action_cooldown > 0 then return false end
    local idx = self.battle.selectedAction or 1
    local actions = player:getActions() or {}
    local action = actions[idx]
    if not action then return false end

    if not player.battle_target and action.getTarget then
        player.battle_target = action.getTarget(player, self.battle)
    end

    if action.try then
        local result = action:try(player, self.battle)
        if result.valid then
            player.pending_action = result.action
            player.pending_action.target = result.target
            player.action_cooldown = action.cooldownStart or 0
            return true
        else
            if result.reason == "not_in_range" then
                gridActions:moveTowardsUnit(player, player.battle_target)
            end
            print("Action not valid: " .. result.reason)
            return false
        end
    else
        -- Fallback for old actions
        print("This action is not converted to the new system yet")
        return false
    end
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