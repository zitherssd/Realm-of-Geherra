-- Ranged Weapons item definitions.

return {
    ["fire_wand"] = {
        id = "fire_wand",
        name = "Fire Wand",
        type = "weapon",
        description = "A carved wand that channels ember magic",
        weight = 1.2,
        value = 220,
        slot = "mainHand",
        grantsSkill = "fireball",
        durability = 15,
        maxDurability = 15,
    },

    ["ice_wand"] = {
        id = "ice_wand",
        name = "Ice Wand",
        type = "weapon",
        description = "A wand that channels biting frost",
        weight = 1.1,
        value = 260,
        slot = "mainHand",
        grantsSkill = "frostbolt",
        durability = 15,
        maxDurability = 15,
    },

    ["storm_wand"] = {
        id = "storm_wand",
        name = "Storm Wand",
        type = "weapon",
        description = "A wand that channels crackling storm energy",
        weight = 1.1,
        value = 300,
        slot = "mainHand",
        grantsSkill = "lightning",
        durability = 15,
        maxDurability = 15,
    },

    ["javelin"] = {
        id = "javelin",
        name = "Javelin",
        type = "weapon",
        description = "A balanced throwing spear",
        weight = 1.5,
        value = 90,
        slot = "rangedWeapon",
        type = "javelin",
        grantsSkill = "javelin_throw",
        durability = 8,
        maxDurability = 8,
        skillModifiers = {
            damageType = "piercing",
            baseDamage = 15,
        },
    },

    ["single_throw_javelin"] = {
        id = "single_throw_javelin",
        name = "Single-Throw Javelin",
        type = "weapon",
        description = "A light skirmisher javelin meant for one decisive throw",
        weight = 1.2,
        value = 45,
        slot = "rangedWeapon",
        grantsSkill = "javelin_throw_single",
        durability = 1,
        maxDurability = 1,
        skillModifiers = {
            damageType = "piercing",
            baseDamage = 15,
        },
    },

    ["sling"] = {
        id = "sling",
        name = "Sling",
        type = "weapon",
        description = "A simple leather sling for hurling stones at a distance",
        weight = 0.5,
        value = 30,
        slot = "rangedWeapon",
        grantsSkill = "sling_stone",
        durability = 20,
        maxDurability = 20,
        skillModifiers = {
            damageType = "blunt",
            baseDamage = 9,
        },
    },
}
