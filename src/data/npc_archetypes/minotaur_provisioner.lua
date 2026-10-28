local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "minotaur_provisioner",
    troopType = "gaia_minotaur_naked",
    title = "Provisioner",
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
}
