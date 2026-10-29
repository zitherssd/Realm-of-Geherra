local Definition = require("src.data.types.faction")
return Definition.new({
    id = "neutral",
    defaultCulture = "generic",
    name = "Neutral",
    color = {
        r = 0.9,
        g = 0.9,
        b = 0.9,
    },
    description = "Animals and unaligned entities.",
})
