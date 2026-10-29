local Definition = require("src.data.types.location_definition")
return Definition.new({
    id = "fort",
    displayName = "Fort",
    mapMarker = "castle",
    placement = {
        weight = 0,
        siteSizes = {
            "major",
        },
        biomeWeights = {
            forest = 2,
            hills = 5,
            mountain = 3,
            plains = 2,
        },
    },
    population = {
        min = 100,
        max = 400,
    },
    prosperity = {
        min = 20,
        max = 60,
    },
    visibility = {
        min = 90,
        max = 130,
    },
    populationProfile = "fort",
    rules = {
        caravanStop = true,
        recoveryStop = true,
        recruitmentPool = "castle",
    },
    actions = {
        {
            label = "Request Audience",
            action = "requestAudience",
        },
    },
    roadWorthy = true,
    hidden = false,
    names = {
        "Hornwatch",
        "Bronzewall",
        "Highwall Fort",
    },
})
