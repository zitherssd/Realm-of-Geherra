local Definition = require("src.data.types.population_profile")
return Definition.new {
    id = "trading_town",
    residents = {
        {id = "elder", role = "elder", count = 1},
        {id = "merchant", role = "wealthy_merchant", count = 1},
        {id = "caravan_leaders", role = "caravan_leader", count = {min = 1, max = 2}},
        {id = "healer", role = "healer", count = 1},
        {id = "tavern_keeper", role = "tavern_keeper", count = 1},
        {id = "extra_merchant", role = "wealthy_merchant", count = 1, chance = 0.25,
            when = {minProsperity = 80}},
    },
}
