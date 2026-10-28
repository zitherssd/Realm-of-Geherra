local Definition = require("src.data.types.location_definition")
return Definition.new {
    id = "bandit_camp",
    displayName = "Bandit Camp",
    mapMarker = "bandit_camp",
    placement = {
        weight = 2,
        siteSizes = {
            "major",
            "minor",
        },
        biomeWeights = {
            desert = 1,
            forest = 3,
            highlands = 3,
            marsh = 2,
            plains = 2,
        },
    },
    population = {
        min = 0,
        max = 0,
    },
    prosperity = {
        min = 0,
        max = 0,
    },
    visibility = {
        min = 10,
        max = 25,
    },
    populationProfile = "bandit_camp",
    rules = {
        caravanStop = false,
        recoveryStop = false,
    },
    actions = {
        {
            label = "Attack Bandit Camp",
            action = "attackBanditCamp",
        },
    },
    roadWorthy = false,
    hidden = true,
    names = {
        "The Sullen Warren",
        "Rattlesnake Gorge",
        "Fang's Rest",
        "The Thorned Cache",
        "Gutterman's Hollow",
        "The Rotted Post",
        "Blood-Marked Grove",
        "Stone-Eye Camp",
        "The Beggar's Mire",
        "Wolfsbane Clearing",
    },
}
