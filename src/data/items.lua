-- data/items.lua
-- Item definitions

return {
    ["bread"] = {
        id = "bread",
        name = "Loaf of Bread",
        type = "food",
        description = "Plain, filling bread",
        weight = 0.5,
        value = 5
    },

    ["dried_meat"] = {
        id = "dried_meat",
        name = "Dried Meat",
        type = "food",
        description = "Salted strips of preserved meat",
        weight = 0.4,
        value = 8
    },

    ["cheese_wedge"] = {
        id = "cheese_wedge",
        name = "Cheese Wedge",
        type = "food",
        description = "A wedge of hard, aged cheese",
        weight = 0.3,
        value = 6
    },

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
            baseDamage = 8
        }
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
            onHitStatuses = { "burn" }
        }
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
            onHitStatuses = { "freeze" }
        }
    },

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
        maxDurability = 15
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
        maxDurability = 15
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
        maxDurability = 15
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
            onHitStatuses = { "paralyze" }
        }
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
            baseDamage = 8,
            range = 0.6
        }
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
            baseDamage = 10
        }
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
            baseDamage = 9
        }
    },

    ["dagger"] = {
        id = "dagger",
        name = "Dagger",
        type = "weapon",
        description = "A short blade suited for close, precise strikes",
        weight = 0.9,
        value = 140,
        slots = {"mainHand", "offHand"},
        grantsSkill = "attack",
        durability = 10,
        maxDurability = 10,
        skillModifiers = {
            damageType = "piercing",
            baseDamage = 5
        },
        requires = {
            attributes = {
                shadowcraft = 1
            }
        }
    },

    ["poison_dagger"] = {
        id = "poison_dagger",
        name = "Poison Dagger",
        type = "weapon",
        description = "A dagger coated with deadly toxin",
        weight = 0.9,
        value = 220,
        slots = {"mainHand", "offHand"},
        grantsSkill = "attack",
        durability = 10,
        maxDurability = 10,
        skillModifiers = {
            damageType = "poison",
            baseDamage = 7,
            onHitStatuses = { "poison" }
        },
        requires = {
            attributes = {
                shadowcraft = 2
            }
        }
    },
    
    ["health_potion"] = {
        id = "health_potion",
        name = "Health Potion",
        type = "consumable",
        description = "Restores 50 health",
        weight = 0.5,
        value = 50,
        effect = {healing = 50}
    },
    
    ["leather_armor"] = {
        id = "leather_armor",
        name = "Leather Armor",
        type = "armor",
        description = "Light leather protection",
        weight = 5.0,
        value = 150,
        stats = {defense = 3},
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

    ["club"] = {
        id = "club",
        name = "Club",
        type = "weapon",
        description = "A simple wooden club",
        weight = 2.0,
        value = 50,
        stats = {attack = 2},
        slot = "mainHand",
        grantsSkill = "attack",
        durability = 12,
        maxDurability = 12,
        skillModifiers = {
            damageType = "blunt",
            baseDamage = 6
        }
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
            baseDamage = 6
        }
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
            baseDamage = 7
        }
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
            baseDamage = 9
        }
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
            baseDamage = 10
        }
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
            baseDamage = 12
        }
    },

    ["wooden_shield"] = {
        id = "wooden_shield",
        name = "Wooden Shield",
        type = "armor",
        description = "A sturdy wooden shield for defense",
        weight = 3.0,
        value = 120,
        stats = {defense = 4},
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
    },

    -- Quest items
    ["sacred_offerings"] = {
        id = "sacred_offerings",
        name = "Sacred Offerings",
        type = "quest",
        description = "Wrapped bundles of herbs, carved tokens, and a small clay amphora of oil — the village's tribute to the old gods.",
        weight = 1.0,
        value = 0,
        questItem = true
    },

    ["sealed_message"] = {
        id = "sealed_message",
        name = "Sealed Message",
        type = "quest",
        description = "A clay tablet wrapped in waxed linen, stamped with the elder's spiral seal. It bears urgent tidings for a nearby settlement.",
        weight = 0.3,
        value = 0,
        questItem = true
    },

    ["bundled_goods"] = {
        id = "bundled_goods",
        name = "Bundled Trade Goods",
        type = "quest",
        description = "A pack of finished bronze tools and a small pouch of crushed gem-dust, meant for trade with a neighbouring village.",
        weight = 2.0,
        value = 0,
        questItem = true
    }
}
