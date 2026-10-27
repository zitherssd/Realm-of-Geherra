local Definition = require("src.data.types.population_profile")
return Definition.new {
    id = "castle",
    residents = {
        {id = "elder", role = "elder", count = 1},
        {id = "trader", role = "trader", count = 1, chance = 0.65},
        {id = "soldier", role = "soldier", count = 1, chance = 0.85},
        {id = "knight", role = "knight", count = 1, chance = 0.45},
    },
}
