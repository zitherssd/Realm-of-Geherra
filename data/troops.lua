-- data/troops.lua
-- Troop/unit definitions

return {
    ["bandit"] = {
        id = "bandit",
        name = "Bandit",
        type = "bandit",
        stats = {
            health = 30,
            strength = 8,
            defense = 3,
            speed = 8
        },
        equipment = {
            mainHand = "iron_sword"
        }
    },
    
    ["soldier"] = {
        id = "soldier",
        name = "Soldier",
        type = "soldier",
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
        stats = {
            health = 80,
            strength = 12,
            defense = 8,
            speed = 6
        },
        equipment = {
            mainHand = "iron_sword",
            body = "leather_armor",
            head = "helmet"
        }
    }
}
