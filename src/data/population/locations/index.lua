local Registry = require("src.data.definition_registry")
return Registry.load("population profile", "src.data.population.locations.", {
    "village", "town", "castle", "shrine", "ruins", "bandit_camp", "windmill", "fort", "trading_town", "chieftain_court", "wizard_tower",
})
