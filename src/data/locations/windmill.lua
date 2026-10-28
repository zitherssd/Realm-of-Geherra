local Definition = require("src.data.types.location_definition")
return Definition.new {
    id = "windmill",
    displayName = "Windmill",
    mapMarker = "windmill",
    placement = {
        weight = 2,
        siteSizes = {
            "major",
            "minor",
        },
        biomeWeights = {
            desert = 1,
            forest = 2,
            highlands = 1,
            marsh = 1,
            plains = 3,
        },
    },
    population = {
        min = 10,
        max = 30,
    },
    prosperity = {
        min = 25,
        max = 45,
    },
    visibility = {
        min = 40,
        max = 60,
    },
    populationProfile = "windmill",
    rules = {
        caravanStop = false,
        recoveryStop = false,
    },
    actions = {},
    roadWorthy = false,
    hidden = false,
    names = {
        "Mill at Amberfield",
        "Sorrowstone Mill",
        "The Wren's Post",
        "Dustmill",
        "Old Crookstone Mill",
        "Hollowridge Windpost",
        "The Granary Rest",
        "Pale Flour Mill",
        "The Crestwood Post",
        "Weary Wheel Mill",
    },
}
