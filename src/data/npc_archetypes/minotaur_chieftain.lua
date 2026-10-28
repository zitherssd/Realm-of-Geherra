local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "minotaur_chieftain",
    troopType = "gaia_minotaur_commander",
    title = "Chieftain",
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
    party = {
        nameSuffix = "Retinue",
        placement = "stationed",
        treasury = {
            min = 50,
            max = 100,
        },
        supplies = 100,
        hostile = false,
        members = {
            {
                id = "minotaurs",
                troopType = "gaia_minotaur_naked",
                count = {
                    min = 3,
                    max = 4,
                },
                chance = 1,
            },
            {
                id = "warhammers",
                troopType = "gaia_minotaur_warhammer",
                count = {
                    min = 2,
                    max = 4,
                },
                chance = 1,
            },
            {
                id = "warrior",
                troopType = "gaia_minotaur_warrior_commander",
                count = 1,
                chance = 0.5,
            },
        },
    },
}
