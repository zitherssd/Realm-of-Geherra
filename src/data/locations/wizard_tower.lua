local LocationDefinition = require("src.data.types.location_definition")
return LocationDefinition.new({
    id = "wizard_tower",
    displayName = "Wizard Tower",
    mapMarker = "shrine",
    placement = {
        weight = 0,
        siteSizes = {
            "major",
            "minor",
        },
        biomeWeights = {
            forest = 4,
            mountain = 3,
        },
    },
    population = {
        min = 1,
        max = 3,
    },
    prosperity = {
        min = 20,
        max = 50,
    },
    visibility = {
        min = 10,
        max = 20,
    },
    populationProfile = "wizard_tower",
    rules = {
        caravanStop = false,
        recoveryStop = false,
    },
    actions = {
        {
            label = "Examine the tower",
            action = "examineWizardTower",
        },
    },
    roadWorthy = false,
    hidden = true,
    names = {
        "The Veiled Spire",
        "Tower of Ash",
        "The Silent Observatory",
    },
})
