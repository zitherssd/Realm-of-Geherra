-- data/units/npcs/npc_units.lua
-- NPC troop definitions

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
        sprite = {
            "assets/sprites/units/town.png",
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
    }
}
