local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "tavern_keeper",
    troopType = "tavern_keeper",
    title = "Tavern Keeper",
    important = true,
    treasury = {
        min = 50,
        max = 150,
    },
    goals = {
        {
            type = "rest_and_recover",
        },
    },
    capabilities = {},
}
