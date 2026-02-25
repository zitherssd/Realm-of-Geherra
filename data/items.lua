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
        stats = {damage = 10}
    },

    ["fire_wand"] = {
        id = "fire_wand",
        name = "Fire Wand",
        type = "weapon",
        description = "A carved wand that channels ember magic",
        weight = 1.2,
        value = 220,
        stats = {damage = 8}
    },

    ["dagger"] = {
        id = "dagger",
        name = "Dagger",
        type = "weapon",
        description = "A short blade suited for close, precise strikes",
        weight = 0.9,
        value = 140,
        stats = {damage = 6}
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
        stats = {defense = 5}
    },
    
    ["gold_coin"] = {
        id = "gold_coin",
        name = "Gold Coin",
        type = "currency",
        description = "Standard currency",
        weight = 0.01,
        value = 1
    }
}
