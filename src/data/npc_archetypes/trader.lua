local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "trader", troopType = "trader", title = "Trader", important = true,
    treasury = {min = 100, max = 300},
    goals = {{type = "rest_and_recover"}},
    capabilities = {},
}
