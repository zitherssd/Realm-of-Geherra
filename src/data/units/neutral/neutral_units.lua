-- data/units/neutral/neutral_units.lua
-- Neutral and shared troop definitions

return {
    ["bandit"] = {
        id = "bandit",
        name = "Bandit",
        type = "bandit",
        sprite = {
            "src/assets/sprites/units/bandit2.png",
            "src/assets/sprites/units/bandit3.png"
        },
        stats = {
            health = 18,
            defense = 9,
            attack = 10,
            speed = 10,
            battle_speed = 10
        },
        equipment = {
            mainHand = "iron_sword",
        },
        size = 3,
        profile = 20,  -- stealthier than a size-3 default (30); harder to spot
        loot = {
            {currency = "gold", chance = 0.6, min = 1, max = 15},
            {id = "iron_sword", chance = 0.1, min = 1, max = 1}
        }
    },

    ["soldier"] = {
        id = "soldier",
        name = "Soldier",
        type = "soldier",
        sprite = "src/assets/sprites/units/heavyinfantry.png",
        stats = {
            health = 24,
            defense = 11,
            attack = 12,
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
        sprite = "src/assets/sprites/units/knight.png",
        stats = {
            health = 45,
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
        sprite = "src/assets/sprites/units/dog.png",
        slots = {"collar"}, -- Can only wear body armor/collar
        stats = {
            health = 12,
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

    ["wolf"] = {
        id = "wolf",
        name = "Wolf",
        type = "beast",
        tags = {"beast", "hostile_wildlife"},
        sprite = "src/assets/sprites/units/direwolf.png",
        stats = {
            health = 18,
            defense = 10,
            attack = 12,
            speed = 15,
            battle_speed = 18,
            strength = 10
        },
        size = 3,
        equipment = {},
        skills = {"bite"},
        loot = {
            {currency = "gold", chance = 0.2, min = 1, max = 5}
        }
    },

    ["bear"] = {
        id = "bear",
        name = "Bear",
        type = "beast",
        tags = {"beast", "hostile_wildlife"},
        -- Placeholder sprite until a dedicated bear sprite exists.
        sprite = "src/assets/sprites/units/bear.png",
        stats = {
            health = 68,
            defense = 7,
            attack = 12,
            speed = 11,
            battle_speed = 12,
            strength = 26
        },
        size = 4,
        equipment = {},
        skills = {"bite"},
        loot = {
            {currency = "gold", chance = 0.5, min = 10, max = 30}
        }
    },

    ["skeleton_sword"] = {
        id = "skeleton_sword",
        name = "Skeleton",
        type = "undead",
        sprite = "src/assets/sprites/units/skeleton.png",
        stats = {
            health = 35,
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
        sprite = "src/assets/sprites/units/skeleton_spear.png",
        stats = {
            health = 35,
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
            "src/assets/sprites/units/town.png",
            "src/assets/sprites/units/town2.png"
        },
        stats = {
            health = 20,
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
        sprite = "src/assets/sprites/units/ogre.png",
        stats = {
            health = 105,
            attack = 14,
            defense = 8,
            speed = 10,
            battle_speed = 10
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
        sprite = "src/assets/sprites/units/dragon.png",
        stats = {
            health = 250,
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
