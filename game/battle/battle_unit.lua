-- game/battle/battle_unit.lua
-- Transient wrapper for an Actor during combat
-- Holds grid position, visual position, and current intent

local BattleUnit = {}
BattleUnit.__index = BattleUnit
local Skills = require("data.skills")

function BattleUnit.new(actor, gridX, gridY, team)
    local self = {
        -- Persistent Data Reference
        actor = actor,
        id = actor.id,
        
        -- Logical State (Grid)
        x = gridX,
        y = gridY,
        team = team or "neutral", -- "player", "enemy", "ally"
        
        -- Visual State (Pixels)
        visualX = 0, 
        visualY = 0,
        
        -- Combat State
        hp = actor.stats.health,
        maxHp = actor.stats.health,
        
        -- Action State
        intent = nil,       -- { type="MOVE", target={x,y} } or { type="SKILL", id="slash", target=unitId }
        cooldowns = {},     -- Map of skill_id -> time_remaining (seconds)
        charges = {},       -- Map of skill_id -> remaining_uses
        globalCooldown = 0  -- GCD timer
    }
    
    setmetatable(self, BattleUnit)
    
    -- Initialize charges for skills that have limits
    if actor.skills then
        for skillId, _ in pairs(actor.skills) do
            local skillData = Skills[skillId]
            if skillData and skillData.maxCharges then
                self.charges[skillId] = skillData.maxCharges
            end
        end
    end
    
    return self
end

-- Helper to check if unit can act
function BattleUnit:canAct()
    return self.hp > 0 and self.globalCooldown <= 0
end

-- Sync visual position immediately to grid (teleport)
function BattleUnit:snapToGrid(cellSize)
    self.visualX = (self.x - 1) * cellSize + (cellSize / 2)
    self.visualY = (self.y - 1) * cellSize + (cellSize / 2)
end

return BattleUnit