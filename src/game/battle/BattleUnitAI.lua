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
        if not unit.battle_target then
            for _, action in ipairs(availableActions) do
                if action.getTarget then
                    unit.battle_target = action.getTarget(unit, battleState)
                    break 
                end
            end
        end

        for _, action in ipairs(availableActions) do
            if action.try then
                local result = action:try(unit, battleState)
                if result.valid then
                    unit.pending_action = result.action
                    unit.pending_action.target = result.target
                    unit.action_cooldown = action.cooldownStart or 0
                    return
                elseif result.reason == "not_in_range" then
                    gridActions:moveTowardsUnit(unit, unit.battle_target)
                    return
                end
            end
        end
    end
end

function BattleUnitAI:init(battle)
    self.battle = battle
end

return BattleUnitAI
