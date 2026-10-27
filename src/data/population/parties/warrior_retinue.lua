local Definition = require("src.data.types.party_template")
return Definition.new {
    id = "warrior_retinue", nameSuffix = "Retinue", placement = "stationed",
    treasury = {min = 50, max = 100}, supplies = 100, hostile = false,
    members = {
        {id = "warriors", role = "retinue_warrior", count = {min = 4, max = 8}},
    },
}
