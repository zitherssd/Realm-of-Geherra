local Definition = require("src.data.types.npc_archetype")
return Definition.new({
    id = "caravan_leader",
    troopType = "soldier",
    title = "Caravan Leader",
    important = true,
    treasury = {
        min = 30,
        max = 80,
    },
    personality = {
        homesickness = {
            0.2,
            0.6,
        },
        responsibility = {
            0.5,
            0.9,
        },
        greed = {
            0.3,
            0.7,
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
        leadCaravan = true,
        travel = true,
    },
})
