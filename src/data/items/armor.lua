-- Armor item definitions.

return {
    ["leather_armor"] = {
        id = "leather_armor",
        name = "Leather Armor",
        type = "armor",
        description = "Light leather protection",
        weight = 5.0,
        value = 150,
        slot = "body",
        durability = 30,
        maxDurability = 30
    },

    ["helmet"] = {
        id = "helmet",
        name = "Helmet",
        type = "armor",
        description = "A protective metal helmet",
        weight = 2.0,
        value = 80,
        stats = {defense = 3},
        slot = "head",
        durability = 20,
        maxDurability = 20
    },

    ["boots"] = {
        id = "boots",
        name = "Leather Boots",
        type = "armor",
        description = "Sturdy leather boots for long travel",
        weight = 1.5,
        value = 75,
        stats = {defense = 2, speed = 1},
        slot = "feet",
        durability = 25,
        maxDurability = 25
    },

    ["furs_armor"] = {
        id = "furs_armor",
        name = "Furs Armor",
        type = "armor",
        description = "Layered furs offering modest padding and warmth",
        weight = 3.0,
        value = 60,
        stats = {defense = 1},
        slot = "body",
        durability = 18,
        maxDurability = 18,
        protections = {
            slashing = 1,
            piercing = 1,
            blunt = 0,
            fire = 0,
            ice = 0,
            shock = 0,
            poison = 0
        }
    },

    ["fur_shoes"] = {
        id = "fur_shoes",
        name = "Fur Shoes",
        type = "armor",
        description = "Soft fur shoes that improve footing in a scuffle",
        weight = 0.8,
        value = 35,
        stats = {defense = 1, attack = 1},
        slot = "feet",
        durability = 14,
        maxDurability = 14
    },

    ["bronze_cap"] = {
        id = "bronze_cap",
        name = "Bronze Cap",
        type = "armor",
        description = "A simple bronze cap that protects vital areas",
        weight = 1.4,
        value = 70,
        slot = "head",
        durability = 20,
        maxDurability = 20,
        protections = {
            slashing = 1,
            piercing = 1,
            blunt = 0,
            fire = 0,
            ice = 0,
            shock = 0,
            poison = 0
        }
    },

    ["wooden_shield"] = {
        id = "wooden_shield",
        name = "Wooden Shield",
        type = "armor",
        description = "A sturdy wooden shield for defense",
        weight = 3.0,
        value = 120,
        stats = {defense = 2},
        slot = "offHand",
        grantsSkill = "shield_bash",
        durability = 18,
        maxDurability = 18,
        protections = {
            slashing = 1,
            piercing = 1,
            blunt = 1,
            fire = 0,
            ice = 0,
            shock = 0,
            poison = 0
        }
    }
}
