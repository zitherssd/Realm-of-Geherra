local Definition = require("src.data.types.location_definition")
return Definition.new {
    id = "trading_town", displayName = "Trading Town", mapMarker = "town",
    placement = {weight = 1, siteSizes = {"major"},
        biomeWeights = {desert = 2, forest = 2, highlands = 2, marsh = 1, plains = 2}},
    population = {min = 1800, max = 4200},
    prosperity = {min = 65, max = 90},
    visibility = {min = 80, max = 110},
    populationProfile = "trading_town",
    rules = {caravanStop = true, recoveryStop = true, recruitmentPool = "town"},
    actions = {},
    roadWorthy = true,
    hidden = false,
    names = {"Copper Crossing", "Amber Market", "River Exchange"},
}
