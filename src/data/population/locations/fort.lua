local Definition = require("src.data.types.population_profile")
return Definition.new {
    id = "fort",
    residents = {
        {id = "commander", role = "fort_commander", count = 1},
        {id = "healer", role = "healer", count = 1, chance = 0.5},
        {id = "quartermaster", role = "quartermaster", count = 1},
    },
    garrison = {role = "fort_guard", leaderSlot = "commander", count = {min = 8, max = 16}, treasury = 100},
}
