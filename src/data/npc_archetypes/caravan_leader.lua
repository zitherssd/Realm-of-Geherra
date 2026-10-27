local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "caravan_leader", troopType = "soldier", title = "Caravan Leader", important = true,
    treasury = {min = 30, max = 80},
    goals = {{type = "provide_service"}, {type = "rest_and_recover"}},
    capabilities = {leadCaravan = true, travel = true},
}
