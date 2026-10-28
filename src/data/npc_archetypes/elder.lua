local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "elder",
    troopType = "elder",
    title = "Elder",
    important = true,
    treasury = {
        min = 40,
        max = 100,
    },
    goals = {
        {
            type = "rest_and_recover",
        },
    },
    capabilities = {},
}
