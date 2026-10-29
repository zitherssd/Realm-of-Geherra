local Definition = require("src.data.types.culture")
return Definition.new({
    id = "minotaur",
    namePool = "minotaur",
    roles = {
        fort_commander = "minotaur_chieftain",
        fort_guard = "minotaur_guard",
        retinue_warrior = "minotaur_guard",
        healer = "minotaur_shaman",
        quartermaster = "minotaur_provisioner",
    },
})
