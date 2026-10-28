local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "pelasgian_healer",
    troopType = "pelas_druid",
    title = "Healer",
    important = true,
    treasury = {
        min = 50,
        max = 150,
    },
    goals = {
        {
            type = "provide_service",
        },
        {
            type = "rest_and_recover",
        },
    },
    capabilities = {
        heal = true,
    },
}
