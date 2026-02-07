local gridActions = require("src.game.battle.BattleGridActions")
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

        if unit.battle_target and (unit.battle_target.health <= 0 or not unit.battle_target.currentCell) then
            unit.battle_target = nil
        end

        if not unit.battle_target then
            for _, action in ipairs(availableActions) do
                if action.getTarget then
                    unit.battle_target = action.getTarget(unit, battleState)
                    break 
                end
            end
        end

        for _, action in ipairs(availableActions) do
            local success, reason = gridActions:tryUseAction(unit, action, battleState)
            if success or reason == "moved" then
                return
            end
        end
    end
end

function BattleUnitAI:init(battle)
    self.battle = battle
end

return BattleUnitAI
