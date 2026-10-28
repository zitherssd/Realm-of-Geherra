local Definition = require("src.data.types.population_profile")
return Definition.new {
    id = "town",
    residents = {
        {
            id = "elder",
            role = "elder",
            count = 1,
        },
        {
            id = "traders",
            role = "trader",
            count = 3,
            chance = 0.6,
        },
        {
            id = "soldiers",
            role = "soldier",
            count = 2,
            chance = 0.15,
        },
        {
            id = "tavern_keeper",
            role = "tavern_keeper",
            count = 1,
        },
    },
}
