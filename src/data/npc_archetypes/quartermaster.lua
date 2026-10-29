local Definition = require("src.data.types.npc_archetype")
return Definition.new({
    id = "quartermaster",
    troopType = "trader",
    title = "Quartermaster",
    important = true,
    treasury = {
        min = 50,
        max = 100,
    },
    goals = {
        {
            type = "rest_and_recover",
        },
    },
    capabilities = {},
})
