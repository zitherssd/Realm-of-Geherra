local Definition = require("src.data.types.culture")
return Definition.new({
    id = "generic",
    namePool = "generic",
    roles = {
        elder = "elder",
        trader = "trader",
        soldier = "soldier",
        knight = "knight",
        tavern_keeper = "tavern_keeper",
        wealthy_merchant = "wealthy_merchant",
        caravan_leader = "caravan_leader",
        healer = "healer",
        fort_commander = "fort_commander",
        fort_guard = "fort_guard",
        retinue_warrior = "fort_guard",
        quartermaster = "quartermaster",
    },
})
