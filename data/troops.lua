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
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor"
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
        }
    },
    
    ["war_dog"] = {
        id = "war_dog",
        name = "War Dog",
        type = "beast",
        sprite = "assets/sprites/units/dog.png",
        slots = {"body"}, -- Can only wear body armor/collar
        stats = {
            health = 25,
            strength = 6,
            defense = 2,
            speed = 10,
            battle_speed = 16
        },
        equipment = {}
    },

    ["companion"] = {
        id = "companion",
        name = "Companion",
        type = "soldier",
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
    }
}
