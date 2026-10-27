local Definition = require("src.data.types.location_definition")
return Definition.new {
    id = "castle", displayName = "Castle", mapMarker = "castle",
    placement = {weight = 2, siteSizes = {"major"},
        biomeWeights = {desert = 1, forest = 1, highlands = 2, marsh = 1, plains = 1}},
    population = {min = 3200, max = 6200},
    prosperity = {min = 55, max = 85},
    visibility = {min = 90, max = 130},
    populationProfile = "castle",
    rules = {caravanStop = true, recoveryStop = true, recruitmentPool = "castle"},
    actions = {{label = "Request Audience", action = "requestAudience"},
        {label = "Train Troops", action = "trainTroops"}},
    roadWorthy = true,
    hidden = false,
    names = {"Fort Varkos", "Red Bastion", "Ironkeep", "Skystone Hold", "Dreadwatch", "Castle Morn", "Northwall Keep", "Blackgate", "Stormhold", "Grimspire"},
}
