local Definition = require("src.data.types.npc_archetype")
return Definition.new({
    id = "wealthy_merchant",
    troopType = "trader",
    title = "Wealthy Merchant",
    important = true,
    treasury = {
        min = 1500,
        max = 2500,
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
            0.4,
            0.9,
        },
    },
    goals = {
        {
            type = "acquire_gold",
            amount = 10000,
        },
        {
            type = "rest_and_recover",
        },
        {
            type = "return_home",
        },
    },
    capabilities = {
        caravanFormation = true,
    },
})
