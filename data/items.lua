-- data/items.lua
-- Item definitions

return {
    ["iron_sword"] = {
        id = "iron_sword",
        name = "Iron Sword",
        type = "weapon",
        description = "A sturdy iron sword",
        weight = 2.5,
        value = 100,
        stats = {damage = 8},
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
        stats = {damage = 10},
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
        stats = {damage = 10},
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
        stats = {damage = 8},
        slot = "mainHand",
        grantsSkill = "fireball",
        durability = 15,
        maxDurability = 15
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
            range = 0.9
        }
    },

    ["javelin"] = {
        id = "javelin",
        name = "Javelin",
        type = "weapon",
        description = "A balanced throwing spear",
        weight = 1.5,
        value = 90,
        stats = {damage = 10},
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

    ["dagger"] = {
        id = "dagger",
        name = "Dagger",
        type = "weapon",
        description = "A short blade suited for close, precise strikes",
        weight = 0.9,
        value = 140,
        stats = {damage = 5},
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
        stats = {damage = 6},
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
        stats = {defense = 5},
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

    ["club"] = {
        id = "club",
        name = "Club",
        type = "weapon",
        description = "A simple wooden club",
        weight = 2.0,
        value = 50,
        stats = {damage = 6},
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
        stats = {damage = 6},
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
        stats = {damage = 7},
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
        stats = {damage = 9},
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
        stats = {damage = 10},
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
        stats = {damage = 12},
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
        stats = {defense = 10},
        slot = "offHand",
        grantsSkill = "shield_bash",
        durability = 15,
        maxDurability = 15,
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
