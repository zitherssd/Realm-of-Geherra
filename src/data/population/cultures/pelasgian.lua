local Definition = require("src.data.types.culture")
return Definition.new({
    id = "pelasgian",
    namePool = "pelasgian",
    roles = {
        fort_commander = "pelasgian_officer",
        fort_guard = "pelasgian_guard",
        retinue_warrior = "pelasgian_guard",
        healer = "pelasgian_healer",
        quartermaster = "pelasgian_quartermaster",
    },
})
