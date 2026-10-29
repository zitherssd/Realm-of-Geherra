local Definition = require("src.data.types.npc_archetype")
return Definition.new({
    id = "healer",
    troopType = "elder",
    title = "Healer",
    important = true,
    treasury = {
        min = 50,
        max = 150,
    },
    personality = {
        homesickness = {
            0.5,
            0.9,
        },
        responsibility = {
            0.6,
            1,
        },
        greed = {
            0.1,
            0.5,
        },
    },
    goals = {
        {
            type = "provide_service",
        },
        {
            type = "rest_and_recover",
        },
        {
            type = "return_home",
        },
    },
    capabilities = {
        heal = true,
    },
})
