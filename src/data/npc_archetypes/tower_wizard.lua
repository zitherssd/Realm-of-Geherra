local NpcArchetype = require("src.data.types.npc_archetype")
return NpcArchetype.new {
    id = "tower_wizard", troopType = "blue_river_astrologer", title = "Wizard", important = true,
    treasury = {min = 100, max = 300}, goals = {{type = "rest_and_recover"}}, capabilities = {},
}
