-- systems/battle/battle_unit_system.lua
-- Small per-unit helpers shared across the battle systems and battle_state.

local Statuses = require("src.data.statuses")

local BattleUnitSystem = {}

-- Can this unit act this tick? (alive, off GCD, not silenced by a status)
function BattleUnitSystem.canAct(unit)
    if unit.hp <= 0 or unit.globalCooldown > 0 then
        return false
    end

    if unit.statusEffects then
        for effectId, effectData in pairs(unit.statusEffects) do
            if type(effectData) == "table" and effectData.remaining and effectData.remaining > 0 then
                local config = Statuses[effectId]
                if config and config.canAct == false then
                    return false
                end
            end
        end
    end

    return true
end

-- Sync visual position immediately to world position (teleport)
function BattleUnitSystem.snapToWorld(unit)
    unit.visualX = unit.x
    unit.visualY = unit.y
end

return BattleUnitSystem
