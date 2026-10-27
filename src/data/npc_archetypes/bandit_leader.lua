local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "bandit_leader", troopType = "bandit", title = "Bandit Leader", important = true,
    treasury = 0,
    goals = {{type = "acquire_gold", amount = 300}},
    capabilities = {raid = true},
}
