local gridActions = require("src.game.battle.BattleGridActions")
local BattleUnitAI = {
    battle = nil
}

function BattleUnitAI:findTarget(unit)
    local closestDist = math.huge
    local closestUnit = nil
    local oppositeParty = nil

    -- Find closest enemy unit
    if(unit.battle_party == 1) then
        oppositeParty = self.battle.enemyParty
    else
        oppositeParty = self.battle.playerParty
    end

    for _, otherUnit in ipairs(oppositeParty.units) do
        if otherUnit.health > 0 then
            local dist = math.abs(otherUnit.currentCell.x - unit.currentCell.x) + 
                        math.abs(otherUnit.currentCell.y - unit.currentCell.y)
            if dist < closestDist then
                closestDist = dist
                closestUnit = otherUnit
            end
        end
    end
    
    return closestUnit
end

function BattleUnitAI:unitTick(unit)

    -- Player AI skip
    if unit.controllable and unit == self.battle.playerUnit then
        if unit.action_cooldown > 0 then
            unit.action_cooldown = unit.action_cooldown - 1
            if unit.action_cooldown <= 0 and unit.pending_action then
                gridActions:executePending(unit, self.battle.currentTick)
            end
        end
        return
    end

    -- Cooldown skip
    if unit.action_cooldown > 0 then
        unit.action_cooldown = unit.action_cooldown - 1
        if unit.action_cooldown <= 0 and unit.pending_action then
            gridActions:executePending(unit, self.battle.currentTick)
        end
        return
    end

    -- Check if current target is still alive, if not, clear it
    if unit.battle_target and unit.battle_target.health <= 0 then
        unit.battle_target = nil
    end

    -- Pick target
    local target = unit.battle_target or self:findTarget(unit)
    if not target then return end

    -- Check if in range for attack
    local dx = math.abs(unit.currentCell.x - target.currentCell.x)
    local dy = math.abs(unit.currentCell.y - target.currentCell.y)
    if (dx + dy) <= 1 then
        gridActions:attack(unit, target) -- Attack if in range
        return true
    end

    return gridActions:moveTowardsUnit(unit, target)
end

function BattleUnitAI:init(battle)
    self.battle = battle
end

return BattleUnitAI
