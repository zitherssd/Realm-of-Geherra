-- data/units/npcs/npc_units.lua
-- NPC troop definitions

return {
    ["player"] = {
        id = "player",
        name = "Player",
        type = "player",
        sprite = "src/assets/sprites/units/commander.png",
        stats = {
            health = 30,
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
        },
        sight = 100,
        profile = 1
    },

    ["companion"] = {
        id = "companion",
        name = "Companion",
        type = "companion",
        tags = {"companion"}, -- Explicitly tag for UI filtering
        sprite = "src/assets/sprites/units/heavyinfantry.png",
        stats = {
            health = 30,
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
        sprite = "src/assets/sprites/units/elder.png",
        stats = {
            health = 60,
            defense = 110,
            attack = 120,
            speed = 7
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor"
        },
        buysFromPlayers = true,
        sellPriceFactor = 0.3,
        restockIntervalDays = 15,
        stock = {
            { id = "bread", quantity = 6 },
            { id = "dried_meat", quantity = 4 },
            { id = "cheese_wedge", quantity = 4 },
            { id = "health_potion", quantity = 2 }
        }
    },

    ["trader"] = {
        id = "trader",
        name = "Trader",
        type = "trader",
        tags = {"civilian", "merchant"},
        sprite = {
            "src/assets/sprites/units/town.png",
            "src/assets/sprites/units/town2.png"
        },
        stats = {
            health = 28,
            defense = 4,
            speed = 7
        },
        equipment = {
            mainHand = "dagger"
        },
        buysFromPlayers = true,
        sellPriceFactor = 0.6,
        stock = {
            { id = "short_sword", quantity = 3 },
            { id = "club", quantity = 3 },
            { id = "leather_armor", quantity = 2 },
            { id = "boots", quantity = 3 },
            { id = "health_potion", quantity = 5 },
            { id = "bread", quantity = 5 }
        }
    },

    ["debug_trader"] = {
        id = "debug_trader",
        name = "Debug Trader",
        type = "debug_trader",
        tags = {"civilian", "merchant"},
        sprite = {
            "src/assets/sprites/units/town.png",
            "src/assets/sprites/units/town2.png"
        },
        stats = {
            health = 28,
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
            "src/assets/sprites/units/town.png",
            "src/assets/sprites/units/town2.png"
        },
        stats = {
            health = 30,
            defense = 4,
            speed = 7
        },
        equipment = {
            mainHand = "dagger"
        }
    }
}
