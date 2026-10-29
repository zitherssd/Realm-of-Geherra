local Definition = require("src.data.types.npc_archetype")
return Definition.new({
    id = "pelasgian_officer",
    troopType = "pelas_chieftain",
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
