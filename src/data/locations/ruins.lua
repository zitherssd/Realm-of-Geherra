local Definition = require("src.data.types.location_definition")
return Definition.new({
    id = "ruins",
    displayName = "Ruins",
    mapMarker = "ruins",
    placement = {
        weight = 2,
        siteSizes = {
            "major",
            "minor",
        },
        biomeWeights = {
            desert = 1,
            forest = 2,
            highlands = 3,
            marsh = 2,
            plains = 1,
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
    populationProfile = "ruins",
    rules = {
        caravanStop = false,
        recoveryStop = false,
    },
    actions = {
        {
            label = "Explore Ruins",
            action = "exploreRuin",
            cooldown = {
                key = "lastExploreDay",
                days = 30,
            },
        },
    },
    roadWorthy = false,
    hidden = true,
    names = {
        "The Hollow Keep",
        "Gravenwall",
        "Ashfeld Remnants",
        "Crestfall Ruins",
        "The Broken Spire",
        "Vordenmoor",
        "The Sunken Hall",
        "Duskwall",
        "The Forgotten Gate",
        "Irenmoth Ruins",
    },
})
