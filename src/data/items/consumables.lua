-- Consumables item definitions.

return {
    ["healing_herbs"] = {
        id = "healing_herbs",
        name = "Healing Herbs",
        type = "consumable",
        description = "Common medicinal herbs used to treat persistent injuries",
        weight = 0.1,
        value = 5,
        stackable = true,
    },
    ["bread"] = {
        id = "bread",
        name = "Loaf of Bread",
        type = "food",
        description = "Plain, filling bread",
        weight = 0.5,
        value = 5,
    },

    ["dried_meat"] = {
        id = "dried_meat",
        name = "Dried Meat",
        type = "food",
        description = "Salted strips of preserved meat",
        weight = 0.4,
        value = 8,
    },

    ["cheese_wedge"] = {
        id = "cheese_wedge",
        name = "Cheese Wedge",
        type = "food",
        description = "A wedge of hard, aged cheese",
        weight = 0.3,
        value = 6,
    },

    ["health_potion"] = {
        id = "health_potion",
        name = "Health Potion",
        type = "consumable",
        description = "Restores 50 health",
        weight = 0.5,
        value = 50,
        effect = {
            healing = 50,
        },
    },
}
