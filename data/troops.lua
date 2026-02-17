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
            attack = 10,
            defense = 10,
            speed = 10,
            battle_speed = 12
        },
        equipment = {
            mainHand = "iron_sword",
            rangedWeapon = "javelin",
            body = "leather_armor"
        },
        loot = {
            {id = "gold_coin", chance = 1.0, min = 10, max = 50},
            {id = "health_potion", chance = 0.2, min = 1, max = 1}
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
            defense = 8,
            attack = 10,
            speed = 8,
            battle_speed = 10
        },
        equipment = {
            mainHand = "iron_sword",
            rangedWeapon = "javelin"
        },
        size = 2,
        loot = {
            {id = "gold_coin", chance = 0.6, min = 1, max = 15},
            {id = "iron_sword", chance = 0.1, min = 1, max = 1}
        }
    },
    
    ["soldier"] = {
        id = "soldier",
        name = "Soldier",
        type = "soldier",
        sprite = "assets/sprites/units/heavyinfantry.png",
        stats = {
            health = 50,
            strength = 10,
            defense = 5,
            speed = 7
        },
        size = 4,
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor"
        },
        loot = {
            {id = "gold_coin", chance = 0.3, min = 1, max = 5}
        }
    },
    
    ["knight"] = {
        id = "knight",
        name = "Knight",
        type = "knight",
        sprite = "assets/sprites/units/knight.png",
        stats = {
            health = 80,
            strength = 12,
            defense = 8,
            speed = 6,
            battle_speed = 9 
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor",
            head = "helmet"
        },
        loot = {
            {id = "gold_coin", chance = 0.8, min = 20, max = 100},
            {id = "helmet", chance = 0.1, min = 1, max = 1}
        }
    },
    
    ["war_dog"] = {
        id = "war_dog",
        name = "War Dog",
        type = "beast",
        tags = {"companion"},
        sprite = "assets/sprites/units/dog.png",
        slots = {"body"}, -- Can only wear body armor/collar
        stats = {
            health = 25,
            strength = 6,
            defense = 2,
            speed = 10,
            battle_speed = 16
        },
        size = 1,
        equipment = {}
    },

    ["companion"] = {
        id = "companion",
        name = "Companion",
        type = "companion",
        tags = {"companion"}, -- Explicitly tag for UI filtering
        sprite = "assets/sprites/units/heavyinfantry.png",
        stats = {
            health = 60,
            strength = 11,
            defense = 6,
            speed = 7
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor"
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
            defense = 6,
            speed = 7
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor"
        }
    }
}
