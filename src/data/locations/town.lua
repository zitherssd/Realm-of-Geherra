local Definition = require("src.data.types.location_definition")
return Definition.new {
    id = "town", displayName = "Town", mapMarker = "town",
    placement = {weight = 3, siteSizes = {"major"},
        biomeWeights = {desert = 2, forest = 2, highlands = 2, marsh = 1, plains = 2}},
    population = {min = 1800, max = 4200},
    prosperity = {min = 45, max = 75},
    visibility = {min = 80, max = 110},
    populationProfile = "town",
    rules = {caravanStop = true, recoveryStop = true, recruitmentPool = "town"},
    actions = {},
    roadWorthy = true,
    hidden = false,
    names = {"Dunhollow", "Ironford", "Westhaven", "Blackmere", "Graywatch", "Highbridge", "Crowport", "Stormcross", "Goldbarrow", "Driftmark"},
}
