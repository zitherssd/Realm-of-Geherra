local Definition = require("src.data.types.population_profile")
return Definition.new {
    id = "chieftain_court",
    residents = {
        -- The chieftain archetype supplies its personal retinue by default.
        {
            id = "chieftain",
            role = "fort_commander",
            count = 1,
        },
        {
            id = "healer",
            role = "healer",
            count = 1,
            chance = 0.5,
        },
        {
            id = "quartermaster",
            role = "quartermaster",
            count = 1,
        },
    },
}
