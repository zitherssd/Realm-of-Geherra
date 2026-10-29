local Definition = require("src.data.types.npc_archetype")
return Definition.new({
    id = "fort_commander",
    troopType = "knight",
    title = "Commander",
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
})
