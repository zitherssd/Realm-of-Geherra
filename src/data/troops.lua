-- data/troops.lua
-- Aggregated troop/unit definitions

local Registry = require("src.data.definition_registry")
local Injuries = require("src.data.injuries")
local groups = {
    require("src.data.units.neutral.neutral_units"),
    require("src.data.units.pelasgians.pelasgian_units"),
    require("src.data.units.npcs.npc_units"),
    require("src.data.units.gaia.gaia_minotaurs"),
    require("src.data.units.gaia.gaia_centaurs"),
    require("src.data.units.gaia.gaia_satyrs"),
    require("src.data.units.gaia.gaia_giants"),
    require("src.data.units.gaia.gaia_animals"),
    require("src.data.units.gaia.gaia_trolls"),
    require("src.data.units.gaia.gaia_nymphs"),
    require("src.data.units.gaia.gaia_plants"),
    require("src.data.units.gaia.gaia_monsters"),
}

local troops = {}

for _, group in ipairs(groups) do
    for unitId, unitDef in pairs(group) do
        Registry.checkId("troop", unitId, unitDef)
        assert(
            unitDef.injuryProfile == nil or Injuries.profiles[unitDef.injuryProfile],
            "Unknown injury profile for troop " .. unitId
        )
        if troops[unitId] then
            error(string.format("Duplicate troop id '%s' found while loading data.troops", unitId))
        end
        troops[unitId] = unitDef
    end
end

return troops
