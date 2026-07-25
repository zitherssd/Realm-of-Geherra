-- data/troops.lua
-- Aggregated troop/unit definitions

local groups = {
    require("data.units.neutral.neutral_units"),
    require("data.units.pelasgians.pelasgian_units"),
    require("data.units.npcs.npc_units")
}

local troops = {}

for _, group in ipairs(groups) do
    for unitId, unitDef in pairs(group) do
        if troops[unitId] then
            error(string.format("Duplicate troop id '%s' found while loading data.troops", unitId))
        end
        troops[unitId] = unitDef
    end
end

return troops
