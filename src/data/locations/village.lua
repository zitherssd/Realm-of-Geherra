local Definition = require("src.data.types.location_definition")
return Definition.new {
    id = "village",
    displayName = "Village",
    mapMarker = "village",
    placement = {
        weight = 4,
        siteSizes = {
            "major",
            "minor",
        },
        biomeWeights = {
            desert = 1,
            forest = 3,
            highlands = 1,
            marsh = 2,
            plains = 3,
        },
    },
    population = {
        min = 500,
        max = 1500,
    },
    prosperity = {
        min = 35,
        max = 60,
    },
    visibility = {
        min = 60,
        max = 90,
    },
    populationProfile = "village",
    rules = {
        caravanStop = true,
        recoveryStop = true,
        recruitmentPool = "village",
    },
    actions = {
        {
            label = "Recruit Volunteers",
            action = "startRecruitmentDialogue",
            cooldown = {
                key = "lastRecruitDay",
                days = 5,
            },
        },
    },
    roadWorthy = true,
    hidden = false,
    names = {
        "Briar Glen",
        "Willowmere",
        "Thornfield",
        "Ashbrook",
        "Mossford",
        "Raven Hollow",
        "Oakrest",
        "Emberfen",
        "Stonebrook",
        "Redmeadow",
    },
}
