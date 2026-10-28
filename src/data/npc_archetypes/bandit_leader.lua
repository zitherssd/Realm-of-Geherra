local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "bandit_leader",
    troopType = "bandit",
    title = "Bandit Leader",
    important = true,
    treasury = 0,
    personality = {
        homesickness = {
            0,
            0.3,
        },
        responsibility = {
            0,
            0.4,
        },
        greed = {
            0.6,
            1,
        },
    },
    goals = {
        {
            type = "acquire_gold",
            amount = 300,
        },
    },
    capabilities = {
        raid = true,
    },
}
