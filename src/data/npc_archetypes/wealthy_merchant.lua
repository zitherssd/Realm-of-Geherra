local Definition = require("src.data.types.npc_archetype")
return Definition.new {
    id = "wealthy_merchant", troopType = "trader", title = "Wealthy Merchant", important = true,
    treasury = {min = 1500, max = 2500},
    goals = {{type = "acquire_gold", amount = 10000}, {type = "rest_and_recover"}},
    capabilities = {caravanFormation = true},
}
