local Registry = require("src.data.definition_registry")
return Registry.load("location", "src.data.locations.", {
    "village",
    "town",
    "castle",
    "shrine",
    "ruins",
    "bandit_camp",
    "windmill",
    "fort",
    "trading_town",
    "wizard_tower",
})
