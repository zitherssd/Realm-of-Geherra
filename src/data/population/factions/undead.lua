local Definition = require("src.data.types.faction")
return Definition.new {
    id = "undead",
    defaultCulture = "generic",
    name = "Undead Forces",
    color = {
        r = 0.3,
        g = 0.0,
        b = 0.3,
    },
    description = "The restless dead.",
}
