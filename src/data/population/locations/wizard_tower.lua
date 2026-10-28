local PopulationProfile = require("src.data.types.population_profile")
return PopulationProfile.new {
    id = "wizard_tower",
    residents = {
        {
            id = "wizard",
            archetype = "tower_wizard",
            count = 1,
        },
    },
}
