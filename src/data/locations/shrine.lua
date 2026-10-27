local Definition = require("src.data.types.location_definition")
return Definition.new {
    id = "shrine", displayName = "Shrine", mapMarker = "shrine",
    placement = {weight = 3, siteSizes = {"major", "minor"},
        biomeWeights = {desert = 1, forest = 3, highlands = 1, marsh = 1, plains = 1}},
    population = {min = 0, max = 0},
    prosperity = {min = 0, max = 0},
    visibility = {min = 15, max = 30},
    populationProfile = "shrine",
    rules = {caravanStop = false, recoveryStop = false},
    actions = {{label = "Pray", action = "pray", cooldown = {key = "lastPrayDay", days = 15}}},
    roadWorthy = false,
    hidden = true,
    names = {"The Pale Altar", "Shrine of Aethon", "The Weeping Stone", "Shroud Hollow", "The Bound Grove", "Omen's Rest", "The Silent Pyre", "Dusk Sanctum", "The Red Idol", "Vigil's End"},
}
