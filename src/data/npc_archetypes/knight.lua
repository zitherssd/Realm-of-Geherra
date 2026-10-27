local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "knight", troopType = "knight", title = "Knight", important = true,
    treasury = {min = 30, max = 100},
    goals = {{type = "rest_and_recover"}},
    capabilities = {},
}
