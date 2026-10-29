local Definition = require("src.data.types.npc_archetype")
return Definition.new({
    id = "traveler",
    troopType = "soldier",
    title = "Traveler",
    important = true,
    treasury = 0,
    goals = {
        {
            type = "rest_and_recover",
        },
    },
    capabilities = {
        travel = true,
    },
})
