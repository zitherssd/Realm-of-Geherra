local Definition = require("src.data.types.party_template")
-- Starts as a world-map party. The leader's existing goals decide whether it moves.
return Definition.new {
    id = "traveling_retinue", nameSuffix = "Retinue", placement = "world",
    treasury = {min = 50, max = 100}, supplies = 100, hostile = false,
    members = {
        {id = "warriors", role = "retinue_warrior", count = {min = 4, max = 8}},
    },
}
