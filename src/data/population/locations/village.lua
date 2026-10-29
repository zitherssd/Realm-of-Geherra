local Definition = require("src.data.types.population_profile")
return Definition.new({
    id = "village",
    residents = {
        {
            id = "elder",
            role = "elder",
            count = 1,
        },
        {
            id = "trader",
            role = "trader",
            count = 1,
            chance = 0.5,
        },
    },
})
