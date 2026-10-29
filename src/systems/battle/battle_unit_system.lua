-- systems/battle/battle_unit_system.lua
-- Small per-unit helpers shared across the battle systems and battle_state.

local Conditions = require("src.systems.actors.conditions")

local BattleUnitSystem = {}

-- Can this unit act this tick? (alive, off GCD, not silenced by a status)
function BattleUnitSystem.canAct(unit)
    if unit.hp <= 0 or unit.escaped or unit.globalCooldown > 0 then
        return false
    end

    return Conditions.permits(unit, "attack") or Conditions.permits(unit, "move") or Conditions.permits(unit, "cast")
end

-- Sync visual position immediately to world position (teleport)
function BattleUnitSystem.snapToWorld(unit)
    unit.visualX = unit.x
    unit.visualY = unit.y
end

return BattleUnitSystem
