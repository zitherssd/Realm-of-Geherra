local Definition = require("src.data.types.name_pool")
return Definition.new {
    id = "generic",
    pools = require("src.data.npc_name_pools"),
}
