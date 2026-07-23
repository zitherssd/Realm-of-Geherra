-- data/troops.lua
-- Troop/unit definitions

return {
    ["player"] = {
        id = "player",
        name = "Player",
        type = "player",
        sprite = "assets/sprites/units/commander.png",
        stats = {
            health = 30,
            strength = 10,
            attack = 30,
            defense = 25,
            speed = 10,
            battle_speed = 10
        },
        equipment = {
            mainHand = "iron_sword",
            rangedWeapon = "javelin",
            body = "leather_armor"
        },
        loot = {
            {currency = "gold", chance = 1.0, min = 10, max = 50},
            {id = "health_potion", chance = 0.2, min = 1, max = 1}
        },
        attributes = {
            command = 1,
            oratory = 1,
            navigation = 0,
            shadowcraft = 1
        }
    },
    
    ["bandit"] = {
        id = "bandit",
        name = "Bandit",
        type = "bandit",
        sprite = {
            "assets/sprites/units/bandit2.png",
            "assets/sprites/units/bandit3.png"
        },
        stats = {
            health = 20,
            strength = 8,
            defense = 20,
            attack = 28,
            speed = 8,
            battle_speed = 10
        },
        equipment = {
            mainHand = "iron_sword",
        },
        size = 2,
        loot = {
            {currency = "gold", chance = 0.6, min = 1, max = 15},
            {id = "iron_sword", chance = 0.1, min = 1, max = 1}
        }
    },
    
    ["soldier"] = {
        id = "soldier",
        name = "Soldier",
        type = "soldier",
        sprite = "assets/sprites/units/heavyinfantry.png",
        stats = {
            health = 35,
            strength = 10,
            defense = 42,
            attack = 37,
            speed = 8
        },
        size = 4,
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor"
        },
        loot = {
            {currency = "gold", chance = 0.3, min = 1, max = 5}
        }
    },
    
    ["knight"] = {
        id = "knight",
        name = "Knight",
        type = "knight",
        sprite = "assets/sprites/units/knight.png",
        stats = {
            health = 45,
            strength = 12,
            defense = 75,
            attack = 70,
            speed = 6,
            battle_speed = 9 
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor",
            head = "helmet"
        },
        loot = {
            {currency = "gold", chance = 0.8, min = 20, max = 100},
            {id = "helmet", chance = 0.1, min = 1, max = 1}
        }
    },
    
    ["war_dog"] = {
        id = "war_dog",
        name = "War Dog",
        type = "beast",
        tags = {"companion"},
        sprite = "assets/sprites/units/dog.png",
        slots = {"collar"}, -- Can only wear body armor/collar
        stats = {
            health = 12,
            strength = 6,
            defense = 18,
            attack = 11,
            speed = 10,
            battle_speed = 16
        },
        size = 3,
        equipment = {},
        skills = {"bite"},
        attributes = {
            tracking = 2
        },
    },

    ["companion"] = {
        id = "companion",
        name = "Companion",
        type = "companion",
        tags = {"companion"}, -- Explicitly tag for UI filtering
        sprite = "assets/sprites/units/heavyinfantry.png",
        stats = {
            health = 30,
            strength = 11,
            defense = 45,
            attack = 34,
            speed = 7
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor"
        },
        attributes = {
            tracking = 2,
            shadowcraft = 1
        }
    },

    ["elder"] = {
        id = "elder",
        name = "Elder",
        type = "elder",
        sprite = "assets/sprites/units/elder.png",
        stats = {
            health = 60,
            strength = 11,
            defense = 110,
            attack = 120,
            speed = 7
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor"
        }
    },

    ["trader"] = {
        id = "trader",
        name = "Trader",
        type = "trader",
        tags = {"civilian", "merchant"},
        sprite = { "assets/sprites/units/town.png",
                "assets/sprites/units/town2.png"
        },
        stats = {
            health = 28,
            strength = 6,
            defense = 4,
            speed = 7
        },
        equipment = {
            mainHand = "dagger"
        }
    },

    ["tavern_keeper"] = {
        id = "tavern_keeper",
        name = "Tavern Keeper",
        type = "tavern_keeper",
        tags = {"civilian", "inn"},
        sprite = {
            "assets/sprites/units/town.png",
            "assets/sprites/units/town2.png"
        },
        stats = {
            health = 30,
            strength = 6,
            defense = 4,
            speed = 7
        },
        equipment = {
            mainHand = "dagger"
        }
    },

    ["skeleton_sword"] = {
        id = "skeleton_sword",
        name = "Skeleton",
        type = "undead",
        sprite = "assets/sprites/units/skeleton.png",
        stats = {
            health = 35,
            strength = 9,
            attack = 28,
            defense = 26,
            speed = 8,
            battle_speed = 11
        },
        size = 3,
        equipment = {
            mainHand = "iron_sword"
        },
        loot = {
            {currency = "gold", chance = 0.5, min = 5, max = 20},
            {id = "iron_sword", chance = 0.15, min = 1, max = 1}
        }
    },

    ["skeleton_spear"] = {
        id = "skeleton_spear",
        name = "Skeleton",
        type = "undead",
        sprite = "assets/sprites/units/skeleton_spear.png",
        stats = {
            health = 35,
            strength = 9,
            attack = 28,
            defense = 26,
            speed = 8,
            battle_speed = 11
        },
        size = 3,
        equipment = {
            mainHand = "spear"
        },
        loot = {
            {currency = "gold", chance = 0.5, min = 5, max = 20},
            {id = "spear", chance = 0.15, min = 1, max = 1}
        }
    },

    ["peasant"] = {
        id = "peasant",
        name = "Peasant",
        type = "peasant",
        sprite = {
            "assets/sprites/units/town.png",
            "assets/sprites/units/town2.png"
        },
        stats = {
            health = 20,
            strength = 5,
            attack = 20,
            defense = 18,
            speed = 6,
            battle_speed = 8
        },
        size = 3,
        equipment = {
            mainHand = "club"
        },
        loot = {
            {currency = "gold", chance = 0.3, min = 1, max = 10}
        }
    },

    ["ogre"] = {
        id = "ogre",
        name = "Ogre",
        type = "ogre",
        sprite = "assets/sprites/units/ogre.png",
        stats = {
            health = 105,
            strength = 16,
            attack = 70,
            defense = 45,
            speed = 5,
            battle_speed = 9
        },
        size = 5,
        equipment = {
            mainHand = "warhammer"
        },
        loot = {
            {currency = "gold", chance = 0.7, min = 30, max = 100},
            {id = "warhammer", chance = 0.2, min = 1, max = 1}
        }
    },

    ["dragon"] = {
        id = "dragon",
        name = "Dragon",
        type = "dragon",
        sprite = "assets/sprites/units/dragon.png",
        stats = {
            health = 250,
            strength = 25,
            attack = 100,
            defense = 100,
            speed = 8,
            battle_speed = 15
        },
        size = 8,
        equipment = {},
        skills = {"fireball"},
        innateProtections = {
            slashing = 2,
            piercing = 3,
            blunt = 2,
            fire = 10,
            ice = 0,
            shock = 0,
            poison = 0
        },
        loot = {
            {currency = "gold", chance = 1.0, min = 500, max = 1000},
            {id = "greatsword", chance = 0.3, min = 1, max = 1}
        }
    }
}
