-- data/equipment.lua
-- Equipment definitions

return {
    ["iron_sword"] = {
        id = "iron_sword",
        name = "Iron Sword",
        slot = "mainHand",
        type = "weapon",
        stats = {damage = 10},
        grantsSkill = "slash"
    },

    ["javelin"] = {
        id = "javelin",
        name = "Javelin",
        slot = "rangedWeapon",
        type = "javelin",
        stats = {damage = 10},
        grantsSkill = "javelin_throw"
    },

    ["fire_wand"] = {
        id = "fire_wand",
        name = "Fire Wand",
        slot = "mainHand",
        type = "wand",
        stats = {damage = 8},
        grantsSkill = "fireball"
    },

    ["dagger"] = {
        id = "dagger",
        name = "Dagger",
        slots = {"mainHand", "offHand"},
        type = "dagger",
        stats = {damage = 6},
        grantsSkill = "dagger",
        requires = {
            attributes = {
                shadowcraft = 1
            }
        }
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
