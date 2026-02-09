-- data/equipment.lua
-- Equipment definitions

return {
    ["iron_sword"] = {
        id = "iron_sword",
        name = "Iron Sword",
        slot = "mainHand",
        type = "weapon",
        stats = {damage = 10}
    },
    
    ["leather_armor"] = {
        id = "leather_armor",
        name = "Leather Armor",
        slot = "body",
        type = "armor",
        stats = {defense = 5}
    },
    
    ["helmet"] = {
        id = "helmet",
        name = "Helmet",
        slot = "head",
        type = "armor",
        stats = {defense = 3}
    },
    
    ["boots"] = {
        id = "boots",
        name = "Leather Boots",
        slot = "feet",
        type = "armor",
        stats = {defense = 2, speed = 1}
    }
}
