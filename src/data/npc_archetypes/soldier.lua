local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "soldier", troopType = "soldier", title = "Soldier", important = true,
    treasury = {min = 5, max = 30},
    goals = {{type = "rest_and_recover"}},
    capabilities = {},
}
