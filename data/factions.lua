-- data/factions.lua
-- Faction definitions

return {
    ["kingdom"] = {
        id = "kingdom",
        name = "The Kingdom",
        color = {r = 0.2, g = 0.5, b = 0.8},
        description = "The ruling kingdom"
    },
    
    ["rebels"] = {
        id = "rebels",
        name = "Rebel Alliance",
        color = {r = 0.8, g = 0.2, b = 0.2},
        description = "Those who resist the kingdom"
    },
    
    ["merchants"] = {
        id = "merchants",
        name = "Merchant Guild",
        color = {r = 0.8, g = 0.8, b = 0.2},
        description = "The trading guild"
    },
    
    ["bandits"] = {
        id = "bandits",
        name = "Bandit Clans",
        color = {r = 0.5, g = 0.2, b = 0.5},
        description = "Organized bandit groups"
    }
}
