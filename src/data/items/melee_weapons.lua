-- Melee Weapons item definitions.

return {
    ["iron_sword"] = {
        id = "iron_sword",
        name = "Iron Sword",
        type = "weapon",
        description = "A sturdy iron sword",
        weight = 2.5,
        value = 100,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 25,
        maxDurability = 25,
        skillModifiers = {
            damageType = "slashing",
            baseDamage = 8,
        },
    },

    ["fire_sword"] = {
        id = "fire_sword",
        name = "Fire Sword",
        type = "weapon",
        description = "A blade wreathed in magical flames",
        weight = 2.5,
        value = 250,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 25,
        maxDurability = 25,
        skillModifiers = {
            damageType = "fire",
            baseDamage = 13,
            onHitStatuses = {
                "burn",
            },
        },
    },

    ["ice_sword"] = {
        id = "ice_sword",
        name = "Ice Sword",
        type = "weapon",
        description = "A blade of crystallized ice and steel",
        weight = 2.5,
        value = 240,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 25,
        maxDurability = 25,
        skillModifiers = {
            damageType = "ice",
            baseDamage = 12,
            onHitStatuses = {
                "freeze",
            },
        },
    },

    ["shock_sword"] = {
        id = "shock_sword",
        name = "Shock Sword",
        type = "weapon",
        description = "A blade crackling with arcs of static",
        weight = 2.4,
        value = 260,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 25,
        maxDurability = 25,
        skillModifiers = {
            damageType = "shock",
            baseDamage = 12,
            onHitStatuses = {
                "paralyze",
            },
        },
    },

    ["spear"] = {
        id = "spear",
        name = "Spear",
        type = "weapon",
        description = "A sturdy melee spear",
        weight = 2.0,
        value = 110,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 22,
        maxDurability = 22,
        skillModifiers = {
            damageType = "piercing",
            baseDamage = 7,
            range = 0.3,
        },
    },

    ["dagger"] = {
        id = "dagger",
        name = "Dagger",
        type = "weapon",
        description = "A short blade suited for close, precise strikes",
        weight = 0.9,
        value = 140,
        slots = {
            "mainHand",
            "offHand",
        },
        grantsSkill = "attack",
        durability = 10,
        maxDurability = 10,
        skillModifiers = {
            damageType = "piercing",
            baseDamage = 6,
            range = 0.2,
        },
        requires = {
            attributes = {
                shadowcraft = 1,
            },
        },
    },

    ["poison_dagger"] = {
        id = "poison_dagger",
        name = "Poison Dagger",
        type = "weapon",
        description = "A dagger coated with deadly toxin",
        weight = 0.9,
        value = 220,
        slots = {
            "mainHand",
            "offHand",
        },
        grantsSkill = "attack",
        durability = 10,
        maxDurability = 10,
        skillModifiers = {
            damageType = "poison",
            baseDamage = 8,
            onHitStatuses = {
                "poison",
            },
        },
        requires = {
            attributes = {
                shadowcraft = 2,
            },
        },
    },

    ["club"] = {
        id = "club",
        name = "Club",
        type = "weapon",
        description = "A simple wooden club",
        weight = 2.0,
        value = 50,
        stats = {
            attack = 2,
        },
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 12,
        maxDurability = 12,
        skillModifiers = {
            damageType = "blunt",
            baseDamage = 8,
        },
    },

    ["quarterstaff"] = {
        id = "quarterstaff",
        name = "Quarterstaff",
        type = "weapon",
        description = "A sturdy wooden staff for combat",
        weight = 2.5,
        value = 60,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 15,
        maxDurability = 15,
        skillModifiers = {
            damageType = "blunt",
            baseDamage = 7,
            range = 0.5,
            windup = 20,
        },
    },

    ["short_sword"] = {
        id = "short_sword",
        name = "Short Sword",
        type = "weapon",
        description = "A practical short sword",
        weight = 1.8,
        value = 80,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 20,
        maxDurability = 20,
        skillModifiers = {
            damageType = "slashing",
            baseDamage = 8,
        },
    },

    ["battle_axe"] = {
        id = "battle_axe",
        name = "Battle Axe",
        type = "weapon",
        description = "A heavy war axe with a keen edge",
        weight = 3.5,
        value = 180,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 30,
        maxDurability = 30,
        skillModifiers = {
            damageType = "slashing",
            baseDamage = 9,
        },
    },

    ["warhammer"] = {
        id = "warhammer",
        name = "Warhammer",
        type = "weapon",
        description = "A heavy hammer designed for warfare",
        weight = 3.5,
        value = 200,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 35,
        maxDurability = 35,
        skillModifiers = {
            damageType = "blunt",
            baseDamage = 10,
        },
    },

    ["greatsword"] = {
        id = "greatsword",
        name = "Greatsword",
        type = "weapon",
        description = "A massive two-handed sword",
        weight = 4.0,
        value = 300,
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 40,
        maxDurability = 40,
        skillModifiers = {
            damageType = "slashing",
            baseDamage = 12,
        },
    },
}
