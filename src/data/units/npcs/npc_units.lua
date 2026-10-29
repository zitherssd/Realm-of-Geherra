-- data/units/npcs/npc_units.lua
-- NPC troop definitions

return {
    ["player"] = {
        id = "player",
        name = "Player",
        type = "player",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/commander.png",
        stats = {
            health = 25,
            attack = 10,
            defense = 10,
            speed = 10,
            strength = 10,
            battle_speed = 10,
        },
        equipment = {
            mainHand = "iron_sword",
            rangedWeapon = "javelin",
            body = "leather_armor",
        },
        loot = {
            {
                currency = "gold",
                chance = 1.0,
                min = 10,
                max = 50,
            },
            {
                id = "health_potion",
                chance = 0.2,
                min = 1,
                max = 1,
            },
        },
        attributes = {
            command = 1,
            oratory = 1,
            navigation = 0,
            shadowcraft = 1,
        },
        sight = 50,
        profile = 15,
    },

    ["companion"] = {
        id = "companion",
        name = "Companion",
        type = "companion",
        injuryProfile = "humanoid",
        tags = {
            "companion",
        },
        -- Explicitly tag for UI filtering
        sprite = "src/assets/sprites/units/heavyinfantry.png",
        stats = {
            health = 30,
            defense = 10,
            attack = 10,
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor",
        },
        attributes = {
            tracking = 2,
            shadowcraft = 1,
        },
    },

    ["elder"] = {
        id = "elder",
        name = "Elder",
        type = "elder",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/elder.png",
        stats = {
            health = 25,
            defense = 11,
            attack = 8,
            speed = 7,
            battle_speed = 7,
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor",
        },
        buysFromPlayers = true,
        sellPriceFactor = 0.3,
        restockIntervalDays = 15,
        stock = {
            {
                id = "healing_herbs",
                quantity = 10,
            },
            {
                id = "bread",
                quantity = 6,
            },
            {
                id = "dried_meat",
                quantity = 4,
            },
            {
                id = "cheese_wedge",
                quantity = 4,
            },
            {
                id = "health_potion",
                quantity = 2,
            },
        },
    },

    ["trader"] = {
        id = "trader",
        name = "Trader",
        type = "trader",
        injuryProfile = "humanoid",
        tags = {
            "civilian",
            "merchant",
        },
        sprite = {
            "src/assets/sprites/units/town.png",
            "src/assets/sprites/units/town2.png",
        },
        stats = {
            health = 28,
            defense = 10,
            attack = 10,
            speed = 11,
            battle_speed = 11,
        },
        equipment = {
            mainHand = "dagger",
        },
        buysFromPlayers = true,
        sellPriceFactor = 0.6,
        stock = {
            {
                id = "short_sword",
                quantity = 3,
            },
            {
                id = "club",
                quantity = 3,
            },
            {
                id = "leather_armor",
                quantity = 2,
            },
            {
                id = "boots",
                quantity = 3,
            },
            {
                id = "health_potion",
                quantity = 5,
            },
            {
                id = "bread",
                quantity = 5,
            },
        },
    },

    ["debug_trader"] = {
        id = "debug_trader",
        name = "Debug Trader",
        type = "debug_trader",
        injuryProfile = "humanoid",
        tags = {
            "civilian",
            "merchant",
        },
        sprite = {
            "src/assets/sprites/units/town.png",
            "src/assets/sprites/units/town2.png",
        },
        stats = {
            health = 28,
            defense = 4,
            speed = 7,
        },
        equipment = {
            mainHand = "dagger",
        },
    },

    ["tavern_keeper"] = {
        id = "tavern_keeper",
        name = "Tavern Keeper",
        type = "tavern_keeper",
        injuryProfile = "humanoid",
        tags = {
            "civilian",
            "inn",
        },
        sprite = {
            "src/assets/sprites/units/town.png",
            "src/assets/sprites/units/town2.png",
        },
        stats = {
            health = 30,
            defense = 10,
            attack = 10,
            speed = 10,
            battle_speed = 10,
        },
        equipment = {
            mainHand = "dagger",
        },
    },
}
